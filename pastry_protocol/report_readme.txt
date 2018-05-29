
Team Members
Name: Rohit Jain
UFID: 8159-7931
*This Time, we did project individually.

Working
Compile Steps: cd pastry_protocol && mix escript.build
Run Example: ./project3 1000 10

Modules: PastryProtocol.MasterActor , PastryProtocol.NodeActor

1. bit = 16 and therefore 
2. Largest network supported or nodeSpace is pow(2,16) i.e. 65536, 
3. b (b as according to paper) is 2 therefore logbase = pow(2,2) = 4
4. number of row in routing table are bit/b = 8
5. leaf set size = pow(2,b+1) = 8

All above parameter can be set in Master actor, and they are not hardcoded.

Node actor get successor node from master and run pastry among them and return 
result(number of hops) to master (for reporting purpose only). 

Largest network, I tested for was 4000 nodes.
