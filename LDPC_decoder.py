import sys
import numpy as np
np.set_printoptions(threshold=sys.maxsize, linewidth=sys.maxsize)

class decoder:
    y = []
    y_j_min = []
    H = []
    E_n = []

    q_0 = []
    q_1 = []
    o_0 = []
    o_1 = []
    P_0 = []
    P_1 = []
    p_0 = []
    p_1 = []

    J = 0
    n = 0

    qnm = []
    rmn = []
    yn = []
    cn = []

    connections = []

    def __init__(self, H):
        super().__init__()
        self.H = H
        self.y_j_min = np.zeros(H.shape[0])
        
        self.q_0 = np.zeros(H.shape)
        self.q_1 = np.zeros(H.shape)
        self.o_0 = np.zeros(H.shape)
        self.o_1 = np.zeros(H.shape)

        self.J = H.shape[0]
        self.n = H.shape[1]

        self.connections = np.array(np.nonzero(H))
        self.qnm = np.zeros(np.count_nonzero(H))
        self.rmn = np.zeros(np.count_nonzero(H))

 
    def setInputMSA(self, y = [], sigma = 1):
        self.y = y
        self.yn = np.zeros(y.shape)
        self.cn = np.zeros(y.shape)
        Lc = 2/(sigma**2)
        self.yn = y*Lc
        for L in range(0,self.n):
            con_index = np.where(self.connections[1] == L)
            self.qnm[con_index] = self.yn[L]
            self.rmn[con_index] = 0

    def setInputSPA_LLR(self, y = [], sigma = 1):
        self.y = y
        self.yn = np.zeros(y.shape)
        self.cn = np.zeros(y.shape)
        Lc = 2/(sigma**2)
        self.yn = y*Lc
        for L in range(0,self.n):
            con_index = np.where(self.connections[1] == L)
            self.qnm[con_index] = self.yn[L]
            self.rmn[con_index] = 0

    def setInputSPA(self, y = [], sigma = 1):
        self.y = y
        self.P_0 = np.zeros(y.shape)
        self.P_1 = np.zeros(y.shape) 
        Lc = 2/(sigma**2)
        LLR = y*Lc
        self.yn = LLR
        self.p_0 = 1/(1+np.exp(LLR))
        self.p_1 = 1-self.p_0

        for (m, n) in np.transpose(self.connections):
            self.q_0[m,n] = self.p_0[n]
            self.q_1[m,n] = self.p_1[n]
            self.o_0[m,n] = 0
            self.o_1[m,n] = 0

    def iterateBitFlip(self, v):
        ### Modified Gallager's Bitflip (no Threshold but flip maximum)
        ### Yu Kou,  Low-density parity-check codes based on finite geometries: a rediscovery and new results, 2001
        S_n = np.mod(v @ np.transpose(self.H), 2)
        if( np.sum(S_n) == 0):
            return True, v

        e_n = S_n @ self.H
        idx = np.argwhere(e_n == np.max(e_n))
        v[idx] = np.mod(v[idx]+1, 2)

        return False, v

    def iterateWeightedBitFlip(self, v):
        ## Weighted Bit Flipping
        ### Yu Kou,  Low-density parity-check codes based on finite geometries: a rediscovery and new results, 2001
        ## not allowed as it introduces Soft-decisions
        ## solution -> add virtual soft-value -> +1 / -1  and a zero for dePuncturing
        ## do to 'virtual' soft-values, this will have no effect on coding gain if no puncturing

        S_n = np.mod(v @ np.transpose(self.H), 2)
        if( np.sum(S_n) == 0):
            return True, v

        for k in range(0, self.H.shape[1]):
            self.E_n[k] = np.sum((2*S_n[self.H[:,k] == 1]-1)*self.y_j_min[self.H[:,k] == 1])

        idx = np.argwhere(self.E_n == np.max(self.E_n))
        v[idx] = np.mod(v[idx]+1, 2)

        return False, v

    def iterateModifiedWeightedBitFlip(self, v, alpha = 0.5):
        ## Weighted Bit Flipping
        ### J. Zhang and M. P. C. Fossorier,  A Modified Weighted Bit-Flipping Decoding of Low-Density Parity-Check Codes, 2004
        ## not allowed as it introduces Soft-decisions
        ## solution -> add virtual soft-value -> +1 / -1  and a zero for dePuncturing
        ## do to 'virtual' soft-values, this will have no effect on coding gain if no puncturing

        S_n = np.mod(v @ np.transpose(self.H), 2)
        if( np.sum(S_n) == 0):
            return True, v

        for k in range(0, self.H.shape[1]):
            self.E_n[k] = np.sum((2*S_n[self.H[:,k] == 1]-1)*self.y_j_min[self.H[:,k] == 1]) - alpha * np.abs(self.y[k])

        idx = np.argwhere(self.E_n == np.max(self.E_n))
        v[idx] = np.mod(v[idx]+1, 2)

        return False, v

    def iterateSumProductAlgorithm(self):
        ### Yu Kou,  Low-density parity-check codes based on finite geometries: a rediscovery and new results, 2001
        for (j, l) in np.transpose(self.connections): #on every 'connection'
            #Compute o_1 and o_0 for each h_j in A_l  
            #(A_l is the set of rows of H that check v_l)

            #o(x,j,l,i) = P(s_j | vl = x, {vt:t <- B(h_j)\l})   x  Prod_t<-B(h_j)\l{ q(x,j,l,i) }
            #P(s_j) = the number of 'bits active' is EVEN:  = 0.5 + 0.5*Prod_i(1-2*Pi_1)
                #p_i = probability incoming bit is 1 -> q(1,i,j).
                #so P(s_j | vl = x, {vt:t <- B(h_j)\l}) is incoming bytes excluding l
            n_index = self.connections[1,np.logical_and( self.connections[0] == j, self.connections[1] != l)]
            prod = np.prod(1 - 2*self.q_1[j, n_index])
            self.o_0[j,l] = 0.5 + 0.5*prod
            self.o_1[j,l] = 1 - self.o_0[j,l]
    
        for (j, l) in np.transpose(self.connections): #on every 'connection'
            #Compute q_1 and q_0 for each h_j in A_l  
            #(A_l is the set of rows of H that check v_l)

            #q(x,j,l,i) = alpha * p_x(l) x  Prod_t<-A_l\l{ o(x,j,l,i) }
            #P(s_j) = the number of 'bits active' is EVEN:  = 0.5 + 0.5*Prod_i(1-2*Pi_1)
                #p_i = probability incoming bit is 1 -> q(1,i,j).
                #so P(s_j | vl = x, {vt:t <- B(h_j)\l}) is incoming bytes excluding l
            m_index = self.connections[0, np.logical_and( self.connections[1] == l, self.connections[0] != j)]

            prod = np.prod(self.o_1[m_index,l])
            self.q_1[j,l] = self.p_1[l]*prod

            prod = np.prod(self.o_0[m_index,l])                
            self.q_0[j,l] = (1 - self.p_1[l])*prod
            
            K = 1/(self.q_1[j,l] + self.q_0[j,l])
            self.q_1[j,l] = K * self.q_1[j,l]
            self.q_0[j,l] = K * self.q_0[j,l]
        
            
            
        ## Check if Code is solved:
        for l in range(0,self.n):
            m_index = self.connections[0, self.connections[1] == l]

            prod = np.prod(self.o_1[m_index,l])
            self.P_1[l] = self.p_1[l]*prod
            prod = np.prod(self.o_0[m_index,l])
            self.P_0[l] = self.p_0[l]*prod

            K = 1/(self.P_1[l] + self.P_0[l])
            self.P_1[l] = K * self.P_1[l]
            self.P_0[l] = K * self.P_0[l]


        z = (self.P_1 > 0.5) * 1
        if (np.sum(np.mod(z @ np.transpose(self.H),2)) == 0):
            return True, z
        else:
            return False, z

    def iterateSumProductAlgorithmTanh(self):
        # Xiao–Yu Hu, Efficient Implementations of the Sum-Product Algorithm for Decoding LDPC Codes  [2001]
        for i, (j, l) in enumerate(np.transpose(self.connections)):
            con_index = np.argwhere( np.logical_and(self.connections[0] == j, self.connections[1] != l) )
            self.rmn[i] = np.prod(np.sign(self.qnm[con_index])) *2*np.arctanh(   np.prod( np.tanh(0.5*np.abs(self.qnm[con_index])) )  )
            
        for i, (j, l) in enumerate(np.transpose(self.connections)): #on every 'connection'
            con_index = np.argwhere( np.logical_and( self.connections[1] == l, self.connections[0] != j ) )
            self.qnm[i] = self.yn[l] + np.sum( self.rmn[con_index] )

        ## Check if Code is solved:
        for l in range(0,self.n):
            con_index = np.argwhere( self.connections[1] == l ) 
            self.cn[l] = self.yn[l] + np.sum(self.rmn[con_index])
        
        z = (self.cn > 0) * 1
        if (np.sum(np.mod(z @ np.transpose(self.H),2)) == 0):
            return True, z
        else:
            return False, z


    def iterateMinimumSumAlgorithm(self):
        # Xiao–Yu Hu, Efficient Implementations of the Sum-Product Algorithm for Decoding LDPC Codes  [2001]
        for i, (j, l) in enumerate(np.transpose(self.connections)):
            con_index = np.argwhere( np.logical_and(self.connections[0] == j, self.connections[1] != l) )
            self.rmn[i] = np.prod(np.sign(self.qnm[con_index])) * np.min(np.abs(self.qnm[con_index]))
            
        for i, (j, l) in enumerate(np.transpose(self.connections)): #on every 'connection'
            con_index = np.argwhere( np.logical_and( self.connections[1] == l, self.connections[0] != j ) )
            self.qnm[i] = self.yn[l] + np.sum( self.rmn[con_index] )

        ## Check if Code is solved:
        for l in range(0,self.n):
            con_index = np.argwhere( self.connections[1] == l ) 
            self.cn[l] = self.yn[l] + np.sum(self.rmn[con_index])
        
        z = (self.cn > 0) * 1
        if (np.sum(np.mod(z @ np.transpose(self.H),2)) == 0):
            return True, z
        else:
            return False, z