cmake_minimum_required(VERSION 3.16)
project(boost_cross_smoke LANGUAGES CXX)

set(Boost_USE_STATIC_LIBS OFF)
find_package(Boost 1.90 CONFIG REQUIRED COMPONENTS filesystem)
add_executable(boost_cross_smoke main.cpp)
target_compile_features(boost_cross_smoke PRIVATE cxx_std_17)
target_link_libraries(boost_cross_smoke PRIVATE Boost::filesystem)
