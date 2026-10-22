#include <boost/filesystem.hpp>
#include <iostream>

int main()
{
    std::cout << boost::filesystem::current_path().string() << '\n';
}
