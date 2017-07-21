#include <chrono>
#include <fstream>
#include <iomanip>
#include <iostream>

#include <tclap/CmdLine.h>


int main(int argc, char** argv)
{
    TCLAP::CmdLine cmd("Hypergraph Case-Base Reasoner", ' ', "0.0.1");

    TCLAP::ValueArg<double> etaArg("e","eta", "Hyperparameter to add an offset to the default class for prediction", false, 0.,"double", cmd);
    TCLAP::ValueArg<double> etaArg("d","delta", "Hyperparameter to control the information treshold.", false, 0.,"double", cmd);

    TCLAP::ValueArg<string> cbFileArg("c", "casebase","File with the casebase description", true, "", "string", cmd);
    TCLAP::ValueArg<string> oFileArg("o", "outcomes","File with the outomes corresponding to the casebase", true, "", "string", cmd);

    cmd.parse(argc, argv);

}