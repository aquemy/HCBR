#include <algorithm>
#include <iostream>
#include <iterator>
#include <vector>

template <typename T>
std::ostream& operator<< (std::ostream& out, const std::vector<T>& v) {
  if ( !v.empty() ) {
    out << '[';
    std::copy (std::begin(v), std::end(v), std::ostream_iterator<T>(out, ", "));
    out << "\b\b]";
  }
  return out;
}
