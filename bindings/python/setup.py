from setuptools import setup, find_packages
# To use a consistent encoding
from codecs import open
from os import path

here = path.abspath(path.dirname(__file__))

# Get the long description from the README file
with open(path.join(here, 'README.md'), encoding='utf-8') as f:
    long_description = f.read()


setup(
    name='HCBR',
    version='0.1.0',
    description='Hypergraph Case-Based Reasoning Python Binding',
    long_description=long_description,
    packages=['hcbr'],
    install_requires=['numpy', 'scikit-learn'],
    setup_requires=['pytest-runner'],
    tests_require=['pytest'],
)