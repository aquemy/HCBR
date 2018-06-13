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

The most usual command line is: ```./hcbr_learning -params <param_file.json>```.

An example of the configuration file with a parameter explanation:
```json
{
    "input": {
        "casebase":"../data/adult_casebase.txt", # Path to the casebase
        "outcomes":"../data/adult_outcomes.txt", # Path to the outcomes
        "features":"../" # Path to the dictionary of features
    },
    "output": {
        "verbose": 0 # Verbose level
    },
    "parameters": {
        "run_id": 0, # Run id used for naming log files
        "seed": 0, # Random generator seed (0 = random)
        "limit": 20000, # Number of examples to use from the casebase
        "sample_out": true,
        "heuristic": false, # Use 'memory heuristic'
        "keep_offset": true,
        "shuffle": false, # Shuffle the casebase
        "online": true, # Adjust model weight with new examples
        "training_iterations": 1, # Number of training iteration
        "no_prediction": false, # Do not generate prediction
        "starting_case": 0
    },
    "hyperparameters":{ # See research paper for hyperparameter meaning
        "bias": 0.0,
        "eta1": 0.0,
        "eta0": 0.0,
        "bar_eta0": 0.0,
        "bar_eta1": 0.0,
        "l1": 0,
        "l0": 1,
        "delta": 0.0,
        "gamma": 0.0
    },
    "serialization": {
        "serialize": true, # Serialize the model
        "path": "./", # Folder in which to serialize
        "weight_file": "W.txt", # Model weight
        "mu0_file": "mu0.txt", # Model strength for class 0
        "mu1_file": "mu1.txt", # Model strength for class 1
        "append_run_number": false # Append run number to files
    },
    "deserialization": {
        "deserialize": false, # Deserialize a model if possible
        "level": "full", # Level of deserialization (full = as much as possible)
        "mu0_file": "Mu_0_post_training.txt", # Model strength for class 0
        "mu1_file": "Mu_1_post_training.txt", # Model strength for class 1
        "path": "./" # Folder in which to look for model files
    }
}
```

# Publications

- **Binary Classification With Hypergraph Case-Based Reasoning**, DOLAP 2018, Alexandre Quemy [[pdf]](http://ceur-ws.org/Vol-2062/paper06.pdf)
- **Binary Classification In Unstructured Space With Hypergraph Case-Based Reasoning**, submitted to Information Systems, Alexandre Quemy
- **Predicting Justice decisions with Hypergraph Case-Based Reasoning**, To appear, Alexandre Quemy
