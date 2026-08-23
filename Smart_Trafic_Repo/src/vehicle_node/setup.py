from setuptools import find_packages, setup

package_name = 'vehicle_node'

setup(
    name=package_name,
    version='0.0.0',
    packages=find_packages(exclude=['test']),
    data_files=[
        ('share/ament_index/resource_index/packages',
            ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
    ],
    install_requires=['setuptools'],
    zip_safe=True,
    maintainer='metinsariaslan',
    maintainer_email='metinsariaslan@todo.todo',
    description='Vehicle node package',
    license='MIT',
    entry_points={
        'console_scripts': [
            'vehicle_node = vehicle_node.vehicle_node:main',
        ],
    },
)