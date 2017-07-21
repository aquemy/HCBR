#include <fstream>
#include <iostream>
#include <iterator>
#include <vector>
#include <sstream>

template <typename T>
std::vector<T> line_to_vect(std::string& line) {
    std::vector<T> v;
    std::istringstream iss(line);
    return std::vector<T>(std::istream_iterator<T>(iss), std::istream_iterator<T>());
}


std::vector<std::vector<int>> read_case_base(std::string path) {
    std::ifstream file(path);
    std::vector<std::vector<int>> cb;
    std::string line;

    if (file) {
        while (std::getline(file, line)) {
            cb.push_back(line_to_vect<int>(line));
        }
    }
    return cb;
}


std::vector<bool> read_mapping(std::string path) {
    std::ifstream file(path);
    std::vector<bool> v;
    std::string line;
    if (file) {
        while (std::getline(file, line)) {
            v.push_back(bool(std::stoi(line)));
        }
    }
    return v;
}
