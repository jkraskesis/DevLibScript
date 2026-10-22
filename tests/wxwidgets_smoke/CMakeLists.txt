cmake_minimum_required(VERSION 3.19)
project(wxwidgets_cross_smoke LANGUAGES CXX)

find_package(wxWidgets CONFIG REQUIRED COMPONENTS core base)
add_executable(wxwidgets_cross_smoke WIN32 main.cpp)
target_compile_features(wxwidgets_cross_smoke PRIVATE cxx_std_17)
target_link_libraries(wxwidgets_cross_smoke PRIVATE wx::core wx::base)
