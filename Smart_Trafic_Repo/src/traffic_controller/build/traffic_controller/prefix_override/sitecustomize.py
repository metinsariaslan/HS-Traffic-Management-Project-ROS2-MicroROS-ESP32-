import sys
if sys.prefix == '/usr':
    sys.real_prefix = sys.prefix
    sys.prefix = sys.exec_prefix = '/home/metinsariaslan/Smart_Trafic_Repo/src/traffic_controller/install/traffic_controller'
