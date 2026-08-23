import sys
if sys.prefix == '/home/metinsariaslan/.espressif/python_env/idf5.2_py3.12_env':
    sys.real_prefix = sys.prefix
    sys.prefix = sys.exec_prefix = '/home/metinsariaslan/Smart_Trafic_Repo/install/vehicle_node'
