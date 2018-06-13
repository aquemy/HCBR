# Requirements & Dependencies:

- Cmake >= 2.8
- Compiler supporting C++17
- Compiler support OpenMP >= 5
- Doxygen (optional)

No external libraries!    
Include [```tclap```](https://github.com/eile/tclap) for the CLI.

# Installation & Build

```
mkdir build && cmake .. -DCMAKE_BUILD_TYPE=Release
```

The build process creates two executables: ```hcbr``` and ```hcbr_learning```. The first is dedicated to sequential learning and temporal dataset while the second one can be used for any dataset. At this moment, it is highly recommended to use the second one only.

# Documentation

The help can be obtained using ```./hcbr_learning -h```.

The most usual command line is: ```./hcbr_learning -params <param_file.json>```

# Publications

- **Binary Classification With Hypergraph Case-Based Reasoning**, DOLAP 2018, Alexandre Quemy [[pdf]](http://ceur-ws.org/Vol-2062/paper06.pdf)
- **Binary Classification In Unstructured Space With Hypergraph Case-Based Reasoning**, submitted to Information Systems, Alexandre Quemy
- **Predicting Justice decisions with Hypergraph Case-Based Reasoning**, To appear, Alexandre Quemy
