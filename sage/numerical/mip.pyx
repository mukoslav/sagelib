include '../ext/stdsage.pxi'

class MIP:
    r"""
    The MIP class is the link between SAGE and LP ( Linear Program ) and 
    MIP ( Mixed Integer Program ) Solvers. Cf : http://en.wikipedia.org/wiki/Linear_programming

    It consists of variables, linear constraints on these variables, and an objective
    function which is to be maximised or minimised under these constraints.

    An instance of ``MIP`` also requires the information
    on the direction of the optimization :
    
    A ``MIP`` ( or ``LP`` ) is defined as a maximization 
    if ``sense=1``, and is a minimization if ``sense=-1``

    INPUT:
        
        - ``sense'' : 
                 * When set to `1` (default), the ``MIP`` is defined as a Maximization 
                 * When set to `-1`, the ``MIP`` is defined as a Minimization 
    
    EXAMPLES::

         sage: ### Computation of a maximum stable set in Petersen's graph ###
         sage: g=graphs.PetersenGraph()
         sage: p=MIP(sense=1)
         sage: b=p.newvar()
         sage: p.setobj(sum([b[v] for v in g]))
         sage: for (u,v) in g.edges(labels=None):
         ...       p.addconstraint(b[u]+b[v],max=1) 
         sage: p.setbinary(b)
         sage: p.solve(objective_only=True)     # optional - requires Glpk or COIN-OR/CBC
         4.0
    """        

    def __init__(self,sense=1):
        r"""
        Constructor for the MIP class

        INPUT:
        
        - ``sense'' : 
                 When set to 1, the MIP is defined as a Maximization 
                 When set to -1, the MIP is defined as a Minimization 

        EXAMPLE:

            sage: p=MIP(sense=1)
        """

        try:
             from sage.numerical.mipCoin import solveCoin
             self.default_solver="Coin"
        except:
             try:
                  from sage.numerical.mipGlpk import solveGlpk
                  self.default_solver="GLPK"
             except:
                  self.default_solver=None
        

        from sage.rings.polynomial.infinite_polynomial_ring import InfinitePolynomialRing
        from sage.rings.real_double import RealDoubleField as RR
        P = InfinitePolynomialRing(RR(), names=('x',)); 
        (self.x,) = P._first_ngens(1)

        self.count=[0]
        self.sense=sense
        self.objective=None
        self.variables={}
        self.constraints=[]
        self.min={}
        self.max={}
        self.types={}
        self.values={}
        self.__BINARY=1
        self.__REAL=-1
        self.__INTEGER=0

    def __repr__(self):
         r"""
         Returns a short description of the MIP
         
         EXAMPLE:
         
         sage: p=MIP()
         sage: v=p.newvar()
         sage: p.addconstraint(v[1]+v[2],max=2)
         sage: print p
         Mixed Integer Program ( maximization, 2 variables, 1 constraints )
         """
         return "Mixed Integer Program ( "+("maximization" if self.sense==1 else "minimization")+", "+str(len(self.variables))+" variables, "+str(len(self.constraints))+" constraints )"

    def newvar(self,dim=1):
        r"""
        Returns an instance of ``MIPVariable`` associated
        to the current instance of ``MIP``.
        
        A new ``MIP`` variable ``x`` defined by :::

            sage: p=MIP()
            sage: x=p.newvar()

        It behaves exactly as an usual dictionary would. It can use any key
        argument you may like, as ``x[5]`` or ``x["b"]``, and has methods 
        ``items()`` and ``keys()``
        
        Any of its fields exists, and is uniquely defined.

        INPUT:

        - ``dim`` ( integer ) : Defines the dimension of the dictionary
                      If ``x`` has dimension `2`, its fields will
                      be of the form ``x[key1][key2]``

        EXAMPLE::

            sage: p=MIP()
            sage: x=p.newvar()
            sage: y=p.newvar(dim=2)
            sage: p.addconstraint(x[2]+y[3][5],max=2)
        """
        return MIPVariable(self.x,self._addElementToRing,dim=dim)
         

    def export(self,format="text"):
         r"""
         Exports the MIP to a string in different formats.
         
         INPUT:
         
         - ``format'' :
                   "text" : human-readable format

         sage: p=MIP()
         sage: x=p.newvar()
         sage: p.setobj(x[1]+x[2])
         sage: p.addconstraint(-3*x[1]+2*x[2],max=2)
         sage: print p.export(format="text")
         Maximization :
           x2 + x1
         Constraints :
           2.0*x2 - 3.0*x1
         Variables :
           x2 is a real variable (min=0.0,max=+oo)
           x1 is a real variable (min=0.0,max=+oo)
         """
         if format=="text":
              value=("Maximization :\n" if self.sense==1 else "Minimization :\n")
              value=value+"  "+(str(self.objective) if self.objective!=None else "Undefined")
              value=value+"\nConstraints :"
              for c in self.constraints:
                   value=value+"\n  "+str(c["function"])
              value=value+"\nVariables :"
              for v in self.variables.keys():
                   value=value+"\n  "+str(v)+" is"
                   if self.isinteger(v):
                       value=value+" an integer variable"
                   elif self.isbinary(v):
                       value=value+" an boolean variable"                       
                   else:
                       value=value+" a real variable"
                   value+=" (min="+(str(self.getmin(v)) if self.getmin(v)!= None else "-oo")+",max="+(str(self.getmax(v)) if self.getmax(v)!= None else "+oo")+")"
              return value

    def get_values(self,*lists):
        r"""
        Return values found by the previous call to ``solve()``

        INPUT:
        
        - Any instance of ``MIPVariable`` ( or one of its elements ), 
          or lists of them.

        OUTPUT:

        - Each instance of ``MIPVariable`` is replaced by a dictionary
           containing the numerical values found for each 
           corresponding variable in the instance
        - Each element of an instance of a ``MIPVariable`` is replaced
           by its corresponding numerical value.

        EXAMPLE::

            sage: p=MIP()
            sage: x=p.newvar()
            sage: y=p.newvar(dim=2)
            sage: p.setobj(x[3]+y[2][9]+x[5])
            sage: p.addconstraint(x[3]+y[2][9]+2*x[5],max=2)
            sage: p.solve() # optional - requires Glpk or COIN-OR/CBC
            2.0
            sage: #
            sage: # Returns the optimal value of x[3]
            sage: p.get_values(x[3]) # optional - requires Glpk or COIN-OR/CBC
            0.0
            sage: #
            sage: # Returns a dictionary identical to x
            sage: # containing values for the corresponding
            sage: # variables
            sage: x_sol=p.get_values(x)
            sage: x_sol.keys()
            [3, 5]
            sage: #
            sage: # Obviously, it also works with
            sage: # variables of higher dimension
            sage: y_sol=p.get_values(y)
            sage: # 
            sage: # We could also have tried :
            sage: [x_sol,y_sol]=p.get_values(x,y)
            sage: # Or
            sage: [x_sol,y_sol]=p.get_values([x,y])
        """

        val=[]
        for l in lists:
            if isinstance(l,MIPVariable):
                if l.depth()==1:
                    c={}
                    for (k,v) in l.items():
                        c[k]=self.values[v] if self.values.has_key(v) else None
                    val.append(c)
                else:
                    c={}
                    for (k,v) in l.items():
                        c[k]=self.get_values(v)
                    val.append(c)                    
            elif isinstance(l,list):
                if len(l)==1:
                    val.append([self.get_values(l[0])])
                else:
                    c=[]
                    [c.append(self.get_values(ll)) for ll in l]
                    val.append(c)
            elif self.variables.has_key(l):
                val.append(self.values[l])
        if len(lists)==1:
            return val[0]
        else:
            return val
                
            

    def show(self):
        r"""
        Prints the MIP in a human-readable way

        EXAMPLE:

        sage: p=MIP()
        sage: x=p.newvar()
        sage: p.setobj(x[1]+x[2])
        sage: p.addconstraint(-3*x[1]+2*x[2],max=2)
        sage: p.show()
        Maximization :
          x2 + x1
        Constraints :
          2.0*x2 - 3.0*x1
        Variables :
          x2 is a real variable (min=0.0,max=+oo)
          x1 is a real variable (min=0.0,max=+oo)
        """
        print self.export(format="text")
        
    #Ok
    def setobj(self,obj):
        r"""
        Sets the objective of the ``MIP``.

        INPUT:
        
        - ``obj`` : A linear function to be optimized

        EXAMPLE::
        
           This code solves the following Linear Program :
           
           Maximize: 
              x + 5 * y
           Constraints:
              x + 0.2 y       <= 4
              1.5 * x + 3 * y   <=4
           Variables:
              x is Real ( min = 0, max = None )
              y is Real ( min = 0, max = None )

           sage: p=MIP(sense=1)
           sage: x=p.newvar()
           sage: p.setobj(x[1]+5*x[2])
           sage: p.addconstraint(x[1]+0.2*x[2],max=4)
           sage: p.addconstraint(1.5*x[1]+3*x[2],max=4)
           sage: p.solve()     # optional - requires Glpk or COIN-OR/CBC
           6.6666666666666661
           
        """
        self.objective=obj

    def addconstraint(self,linear_function,max=None,min=None):
        r"""
        Adds a constraint to the MIP
        
        INPUT :

        - ``consraint`` : : A linear function
        - ``max``  : An upper bound on the constraint ( set to ``None`` by default )
        - ``min``  : A lower bound on the constraint

        EXAMPLE::
        
           This code solves the following Linear Program :
           
           Maximize: 
              x + 5 * y
           Constraints:
              x + 0.2 y       <= 4
              1.5 * x + 3 * y   <=4
           Variables:
              x is Real ( min = 0, max = None )
              y is Real ( min = 0, max = None )

           sage: p=MIP(sense=1)
           sage: x=p.newvar()
           sage: p.setobj(x[1]+5*x[2])
           sage: p.addconstraint(x[1]+0.2*x[2],max=4)
           sage: p.addconstraint(1.5*x[1]+3*x[2],max=4)
           sage: p.solve()     # optional - requires Glpk or COIN-OR/CBC
           6.6666666666666661
        """

        max=float(max) if max!=None else None
        min=float(min) if min!=None else None
        self.constraints.append({"function":linear_function,"min":min, "max":max,"card":len(linear_function.variables())})

    def setbinary(self,e):
        r"""
        Sets a variable or a ``MIPVariable`` as binary

        INPUT:

        - ``e`` : An instance of ``MIPVariable`` or one of
                  its elements

        NOTE:

        We recommend you to define the types of your variables after
        your problem has been completely defined ( see example )

        EXAMPLE:

          sage: p=MIP()
          sage: x=p.newvar()
          sage: #
          sage: # The following instruction does absolutely nothing
          sage: # as none of the variables of x have been used yet
          sage: p.setbinary(x)
          sage: p.setobj(x[0]+x[1])
          sage: p.addconstraint(-3*x[0]+2*x[1],max=2)
          sage: #
          sage: # This instructions sets x[0] and x[1]
          sage: # as binary variables
          sage: p.setbinary(x)
          sage: p.addconstraint(x[3]+x[2],max=2)
          sage: #
          sage: # x[3] is not set as binary
          sage: # as no setbinary(x) has been called
          sage: # after its first definition
          sage: #
          sage: # Now it is done 
          sage: p.setbinary(x[3])
        """
        if isinstance(e,MIPVariable):
            if e.depth()==1:
                for v in e.values():
                    self.types[v]=self.__BINARY                
            else:
                for v in e.keys():
                    self.setbinary(e[v])
        elif self.variables.has_key(e):        
            self.types[e]=self.__BINARY
        else:
            raise Exception("Wrong kind of variable..")

    def isbinary(self,e):
        r"""
        Tests whether the variable is binary.

        ( Variables are real by default )

        INPUT:

        - ``e`` : a variable ( not a ``MIPVariable``, but one of its elements ! )

        OUTPUT:

        ``True`` if the variable is binary, ``False`` otherwise

        EXAMPLE:

            sage: p=MIP()
            sage: v=p.newvar()
            sage: p.setobj(v[1])
            sage: p.isbinary(v[1])
            False
            sage: p.setbinary(v[1])            
            sage: p.isbinary(v[1])
            True
        """
        # Returns an exception if the variable does not exist.. 
        # For exemple if the users tries to find out the type of
        # a MIPVariable or anything else
        self.variables[e]

        if self.types.has_key(e) and self.types[e]==self.__BINARY:
            return True
        return False

    def setinteger(self,e):
        r"""
        Sets a variable or a ``MIPVariable`` as integer

        INPUT:

        - ``e`` : An instance of ``MIPVariable`` or one of
                  its elements

        NOTE:

        We recommend you to define the types of your variables after
        your problem has been completely defined ( see example )

        EXAMPLE:

          sage: p=MIP()
          sage: x=p.newvar()
          sage: #
          sage: # The following instruction does absolutely nothing
          sage: # as none of the variables of x have been used yet
          sage: p.setinteger(x)
          sage: p.setobj(x[0]+x[1])
          sage: p.addconstraint(-3*x[0]+2*x[1],max=2)
          sage: #
          sage: # This instructions sets x[0] and x[1]
          sage: # as integer variables
          sage: p.setinteger(x)
          sage: p.addconstraint(x[3]+x[2],max=2)
          sage: #
          sage: # x[3] is not set as integer
          sage: # as no setinteger(x) has been called
          sage: # after its first definition
          sage: #
          sage: # Now it is done 
          sage: p.setinteger(x[3])
        """
        if isinstance(e,MIPVariable):
            if e.depth()==1:
                for v in e.values():
                    self.types[v]=self.__INTEGER                
            else:
                for v in e.keys():
                    self.setbinary(e[v])
        elif self.variables.has_key(e):        
            self.types[e]=self.__INTEGER
        else:
            raise Exception("Wrong kind of variable..")

    def isinteger(self,e):
        r"""
        Tests whether the variable is integer.

        ( Variables are real by default )

        INPUT:

        - ``e`` : a variable ( not a ``MIPVariable``, but one of its elements ! )

        OUTPUT:

        ``True`` if the variable is integer, ``False`` otherwise

        EXAMPLE:

            sage: p=MIP()
            sage: v=p.newvar()
            sage: p.setobj(v[1])
            sage: p.isinteger(v[1])
            False
            sage: p.setinteger(v[1])            
            sage: p.isinteger(v[1])
            True
        """
        # Returns an exception if the variable does not exist.. 
        # For exemple if the users tries to find out the type of
        # a MIPVariable or anything else
        self.variables[e]

        if self.types.has_key(e) and self.types[e]==self.__INTEGER:
            return True
        return False

    def setreal(self,e):
        r"""
        Sets a variable or a ``MIPVariable`` as real

        INPUT:

        - ``e`` : An instance of ``MIPVariable`` or one of
                  its elements

        NOTE:

        We recommend you to define the types of your variables after
        your problem has been completely defined ( see example )

        EXAMPLE:

          sage: p=MIP()
          sage: x=p.newvar()
          sage: #
          sage: # The following instruction does absolutely nothing
          sage: # as none of the variables of x have been used yet
          sage: p.setreal(x)
          sage: p.setobj(x[0]+x[1])
          sage: p.addconstraint(-3*x[0]+2*x[1],max=2)
          sage: #
          sage: # This instructions sets x[0] and x[1]
          sage: # as real variables
          sage: p.setreal(x)
          sage: p.addconstraint(x[3]+x[2],max=2)
          sage: #
          sage: # x[3] is not set as real
          sage: # as no setreal(x) has been called
          sage: # after its first definition
          sage: # ( even if actually, it is as variables
          sage: # are real by default ... )
          sage: #
          sage: # Now it is done 
          sage: p.setreal(x[3])
        """
        if isinstance(e,MIPVariable):
            if e.depth()==1:
                for v in e.values():
                    self.types[v]=self.__REAL                
            else:
                for v in e.keys():
                    self.setbinary(e[v])
        elif self.variables.has_key(e):        
            self.types[e]=self.__REAL
        else:
            raise Exception("Wrong kind of variable..")


    def isreal(self,e):
        r"""
        Tests whether the variable is real.

        ( Variables are real by default )

        INPUT:

        - ``e`` : a variable ( not a ``MIPVariable``, but one of its elements ! )

        OUTPUT:

        ``True`` if the variable is real, ``False`` otherwise

        EXAMPLE:

            sage: p=MIP()
            sage: v=p.newvar()
            sage: p.setobj(v[1])
            sage: p.isreal(v[1])
            True
            sage: p.setbinary(v[1])
            sage: p.isreal(v[1])
            False
            sage: p.setreal(v[1])            
            sage: p.isreal(v[1])
            True
        """
        
        # Returns an exception if the variable does not exist.. 
        # For exemple if the users tries to find out the type of
        # a MIPVariable or anything else
        self.variables[e]

        if (not self.types.has_key(e)) or self.types[e]==self.__REAL:
            return True
        return False


    def solve(self,solver=None,log=False,objective_only=False):
        r"""
        Solves the MIP.

        INPUT :
        - ``solver'' :
                 3 solvers should be available through this class :
                     - GLPK ( ``solver="GLPK"`` )
                     http://www.gnu.org/software/glpk/
                     
                     - COIN Branch and Cut  ( ``solver="Coin"`` )
                     COIN-OR http://www.coin-or.org/
                     If the spkg is installed
                     
                     - CPLEX  ( ``solver="CPLEX"`` )
                     http://www.ilog.com/products/cplex/
                     Not Implemented Yet
                     
                     ``solver`` should then be equal to one of ``"GLPK"``, 
                     ``"Coin"``, ``"CPLEX"``, or ``None``.
                     If ``solver=None`` ( default ), the default solver is used 
                     ( Coin if available, GLPK otherwise )
                     
        - ``log`` : This boolean variable indicates whether progress should be printed 
                    during the computations.
        
        - ``objective_only`` : Boolean variable 
                          * When set to ``True``, only the objective function is returned
                          * When set to ``False`` (default), the optimal
                            numerical values are stored ( takes computational 
                            time )

        OUTPUT :
        
        The optimal value taken by the objective function
        
        EXAMPLE :
        
        This code solves the following Linear Program :

           Maximize: 
              x + 5 * y
           Constraints:
              x + 0.2 y       <= 4
              1.5 * x + 3 * y   <=4
           Variables:
              x is Real ( min = 0, max = None )
              y is Real ( min = 0, max = None )


           sage: p=MIP(sense=1)
           sage: x=p.newvar()
           sage: p.setobj(x[1]+5*x[2])
           sage: p.addconstraint(x[1]+0.2*x[2],max=4)
           sage: p.addconstraint(1.5*x[1]+3*x[2],max=4)
           sage: p.solve()           # optional - requires Glpk or COIN-OR/CBC
           6.6666666666666661
           sage: p.get_values(x)     # optional - requires Glpk or COIN-OR/CBC
           {1: 0.0, 2: 1.3333333333333333}

           sage: ### Computation of a maximum stable set in Petersen's graph ###
           sage: g=graphs.PetersenGraph()
           sage: p=MIP(sense=1)
           sage: b=p.newvar()
           sage: p.setobj(sum([b[v] for v in g]))
           sage: for (u,v) in g.edges(labels=None):
           ...       p.addconstraint(b[u]+b[v],max=1) 
           sage: p.setbinary(b)
           sage: p.solve(objective_only=True)     # optional - requires Glpk or COIN-OR/CBC
           4.0


        """        

        if self.objective==None:
            raise Exception("No objective function has been defined !")

        if solver==None:
            solver=self.default_solver

        if solver==None:
             raise Exception("There does not seem to be any solver installed...\n Please visit http://www.sagemath.org/doc/tutorial/tour_LP.html for more informations")
        elif solver=="Coin":
             try:
                  from sage.numerical.mipCoin import solveCoin
             except:
                raise NotImplementedError("Coin/CBC is not installed and cannot be used to solve this MIP\n To install it, you can type in Sage : sage: install_package('cbc')")                
             return solveCoin(self,log=log,objective_only=objective_only)

        elif solver=="GLPK":
             try:
                  from sage.numerical.mipGlpk import solveGlpk
             except:
                raise NotImplementedError("GLPK is not installed and cannot be used to solve this MIP\n To install it, you can type in Sage : sage: install_package('glpk')")                
             return solveGlpk(self,log=log,objective_only=objective_only)
        elif solver=="CPLEX":
             raise NotImplementedError("The support for CPLEX is not written yet... We're seriously thinking about it, though ;-)")
        else:
            raise NotImplementedError("solver should be set to 'GLPK', 'Coin', 'CPLEX' or None (in which case the default one is used).")


    def _NormalForm(self,exp):
        r"""
        Returns a dictionary built from the linear function

        INPUT:

        - ``exp`` : The expression representing a linear function

        OUTPUT:

        A dictionary whose keys are the id of the variables, and whose
        values are their coefficients.
        The value corresponding to key `-1` is the constant coefficient

        EXAMPLE:

            sage: p=MIP()
            sage: v=p.newvar()
            sage: p._NormalForm(v[0]+v[1])
            {1: 1.0, 2: 1.0, -1: 0.0}
        """
        d=dict(zip([self.variables[v] for v in exp.variables()],exp.coefficients()))
        d[-1]=exp.constant_coefficient()
        return d

    def _addElementToRing(self):
        r"""
        Creates a new variable from the main ``InfinitePolynomialRing``

        OUTPUT:

        - The newly created variable

        EXAMPLE:

            sage: p=MIP()
            sage: v=p.newvar()
            sage: p.count[0]
            0
            sage: p._addElementToRing()
            x1
            sage: p.count[0]
            1
        """
        self.count[0]+=1
        v=self.x[self.count[0]]
        self.variables[v]=self.count[0]
        self.types[v]=self.__REAL
        self.min[v]=0.0
        return v

    def setmin(self,v,min):
        r"""
        Sets the minimum value of a variable

        INPUT

        - ``v`` : a variable ( not a ``MIPVariable``, but one of its elements ! )
        - ``min`` : the minimum value the variable can take
                    when ``min=None``, the variable has no lower bound

        EXAMPLE::

            sage: p=MIP()
            sage: v=p.newvar()
            sage: p.setobj(v[1])
            sage: p.getmin(v[1])
            0.0
            sage: p.setmin(v[1],6)
            sage: p.getmin(v[1])
            6.0
        """
        self.min[v]=min

    def setmax(self,v,max):
        r"""
        Sets the maximum value of a variable

        INPUT

        - ``v`` : a variable ( not a ``MIPVariable``, but one of its elements ! )
        - ``max`` : the maximum value the variable can take
                    when ``max=None``, the variable has no upper bound

        EXAMPLE::

            sage: p=MIP()
            sage: v=p.newvar()
            sage: p.setobj(v[1])
            sage: p.getmax(v[1])
            sage: p.setmax(v[1],6)
            sage: p.getmax(v[1])
            6.0
        """
        self.max[v]=max


    def getmin(self,v):
        r"""
        Returns the minimum value of a variable

        INPUT

        - ``v`` a variable ( not a ``MIPVariable``, but one of its elements ! )

        OUTPUT

        Minimum value of the variable, or ``None`` is
        the variable has no lower bound

        EXAMPLE::

            sage: p=MIP()
            sage: v=p.newvar()
            sage: p.setobj(v[1])
            sage: p.getmin(v[1])
            0.0
            sage: p.setmin(v[1],6)
            sage: p.getmin(v[1])
            6.0
        """
        return float(self.min[v]) if self.min.has_key(v) else 0.0
    def getmax(self,v):
        r"""
        Returns the maximum value of a variable

        INPUT

        - ``v`` a variable ( not a ``MIPVariable``, but one of its elements ! )

        OUTPUT

        Maximum value of the variable, or ``None`` is
        the variable has no upper bound

        EXAMPLE::

            sage: p=MIP()
            sage: v=p.newvar()
            sage: p.setobj(v[1])
            sage: p.getmax(v[1])
            sage: p.setmax(v[1],6)
            sage: p.getmax(v[1])
            6.0
        """
        return float(self.max[v]) if self.max.has_key(v) else None

class MIPSolverException(Exception):
    r"""
    Exception raised when the solver fails
    """
    def __init__(self, value):
        r"""
        Constructor for ``MIPSolverException``

        ``MIPSolverException`` is the exception raised when the solver fails

        EXAMPLE:

            sage: MIPSolverException("Error")
            MIPSolverException()
                    
        """
        self.value = value
    def __str__(self):
        r"""
        Returns the value of the instance of ``MIPSolverException` `

        EXAMPLE:

            sage: e=MIPSolverException("Error")
            sage: print e
            'Error'
        """
        return repr(self.value)

class MIPVariable:
     r"""
     ``MIPVariable`` is a variable used by the class ``MIP``
     """
     def __init__(self,x,f,dim=1):
         r"""
         Constructor for ``MIPVariable``

         INPUT:

         - ``x`` is the generator element of an ``InfinitePolynomialRing``
         - ``f`` is a function returning a new variable from the parent class
         - ``dim`` is the integer defining the definition of the variable

         For more informations, see method ``MIP.newvar``

         EXAMPLE:

            sage: p=MIP()
            sage: v=p.newvar()
            
            
         """
         self.dim=dim
         self.dict={}
         self.x=x
         self.f=f

     def __getitem__(self,i):
          r"""
          Returns the symbolic variable corresponding to the key

          Returns the element asked, otherwise creates it.
          ( When depth>1, recursively creates the variables )

         EXAMPLE:

             sage: p=MIP()
             sage: v=p.newvar()
             sage: p.setobj(v[0]+v[1])
             sage: v[0]
             x1
          """
          if self.dict.has_key(i):
               return self.dict[i] 
          elif self.dim==1:
              self.dict[i]=self.f()
              return self.dict[i]
          else:
               self.dict[i]=MIPVariable(dim=self.dim-1,x=self.x, f=self.f)
               return self.dict[i]
     def keys(self):
         r"""
         Returns the keys already defined in the dictionary

         EXAMPLE:

             sage: p=MIP()
             sage: v=p.newvar()
             sage: p.setobj(v[0]+v[1])
             sage: v.keys()
             [0, 1]
         """
         return self.dict.keys()
     def items(self):
         r"""
         Returns the pairs (keys,value) contained in the dictionary

         EXAMPLE:

             sage: p=MIP()
             sage: v=p.newvar()
             sage: p.setobj(v[0]+v[1])
             sage: v.items()
             [(0, x1), (1, x2)]
         """
         return self.dict.items()
     def depth(self):
         r"""
         Returns the current variable's depth

         EXAMPLE:

             sage: p=MIP()
             sage: v=p.newvar()
             sage: p.setobj(v[0]+v[1])
             sage: v.depth()
             1
         """
         return self.dim
     def values(self):
         r"""
         Returns the symbolic variables associated to the current dictionary

         EXAMPLE:

             sage: p=MIP()
             sage: v=p.newvar()
             sage: p.setobj(v[0]+v[1])
             sage: v.values()
             [x1, x2]
         """
         return self.dict.values()

