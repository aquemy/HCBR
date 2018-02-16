#include <algorithm>
#include <fstream>
#include <iostream>
#include <iterator>
#include <vector>
#include <cstdio>
#include <memory>
#include <stdexcept>
#include <string>
#include <array>


#include <json.hpp>

#ifndef HCBR_UTILS_HPP
#define HCBR_UTILS_HPP

////////////////////////////////////////////////////////////
/// \brief Parse and validate json parameters
///
/// \param out Stream to output the result
/// \param v Vector to display
///
/// \return std::ostream The stream
////////////////////////////////////////////////////////////
nlohmann::json load_and_validate_parameters(std::string param_file_path) {
	std::ifstream param_file(param_file_path);
    std::stringstream stream;
    stream << param_file.rdbuf();
    auto params = nlohmann::json::parse(stream.str());

    return params;
}

////////////////////////////////////////////////////////////
/// \brief Print a vector
///
/// \param out Stream to output the result
/// \param v Vector to display
///
/// \return std::ostream The stream
////////////////////////////////////////////////////////////
template <typename T>
std::ostream& operator<< (std::ostream& out, const std::vector<T>& v) {
  if ( !v.empty() ) {
    //out << '[';
    std::copy(std::begin(v), std::end(v), std::ostream_iterator<T>(out, " "));
    //out << "\b\b]";
  }
  return out;
}

std::string exec(const char* cmd) {
    std::array<char, 128> buffer;
    std::string result;
    std::shared_ptr<FILE> pipe(popen(cmd, "r"), pclose);
    if (!pipe) throw std::runtime_error("popen() failed!");
    while (!feof(pipe.get())) {
        if (fgets(buffer.data(), 128, pipe.get()) != nullptr)
            result += buffer.data();
    }
    return result;
}


void data_sanity_check(const std::vector<std::vector<int>>& cases, const std::vector<int>& outcomes) {
    int empty_cases = 0;
    for(const auto& c: cases) {
        if(std::size(c) == 0) {
             empty_cases++;
        }
    }
    if(empty_cases > 0) {
        std::cerr << "[WARNING] There are " << empty_cases << " empty input vectors";
        std::cerr << "[WARNING] The prevalence of empty cases is " << empty_cases / double(std::size(cases)) << std::endl;
    }

}

#endif
