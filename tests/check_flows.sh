#!/usr/bin/env bash
# Variables and command overrides are used by the sourced build script.
# shellcheck disable=SC2034,SC2329
set -e
cd "$(dirname "$0")/.."

# Every build runs in a subshell with filesystem-changing commands blocked.
function check_flow
(
	function unexpected { echo "Unexpected action: $*" >&2; exit 99; }
	function mkdir { unexpected mkdir "$@"; }
	function rm { unexpected rm "$@"; }
	function wget { unexpected wget "$@"; }
	function tar { unexpected tar "$@"; }
	function tee { unexpected tee "$@"; }
	function make { unexpected make "$@"; }
	function ninja { unexpected ninja "$@"; }
	function cmake { unexpected cmake "$@"; }
	function x86_64-w64-mingw32-g++ { echo x86_64-w64-mingw32; }
	SRC_DIR=/nonexistent/devlib-test/src
	INSTALL_DIR=/nonexistent/devlib-test/install
	LOG_DIR=/nonexistent/devlib-test/logs
	if [ "$1" = mingw ]; then
		function uname { echo MINGW64_NT; }
		function pwd { echo C:/msys64/home/test; }
		function cc { printf '#define __GNUC__ 16\n'; }
	fi
	shift
	source ./build_devlib.sh "$@"
)

for platform in linux mingw; do
	for buildtool in configure cmake both; do
		for compiler in gcc clang both; do
			check_flow "$platform" --dry-run --compiler "$compiler" --buildtool "$buildtool" all >/dev/null
		done
	done
done
output=$(check_flow mingw --dry-run boost)
[[ "$output" == *'Auto detected gcc as default cc compiler'* && "$output" == *'COMPILER: gcc'* ]]

output=$(check_flow linux --dry-run --target x86_64-w64-mingw32 --compiler gcc --buildtool cmake boost)
[[ "$output" == *'./bootstrap.sh gcc'* && "$output" == *'toolset=gcc-mingw target-os=windows'* ]]

for selector in messaging application unknown; do
	if check_flow linux all "$selector" >/dev/null 2>&1; then
		echo "Unexpected acceptance: $selector" >&2
		exit 1
	fi
done
output=$(check_flow linux --dry-run --target x86_64-w64-mingw32 --compiler gcc --buildtool cmake all)
[[ "$output" == *'-DwxBUILD_TOOLKIT=msw'* && "$output" == *'cmake --install'* ]]
output=$(check_flow linux --dry-run --target x86_64-w64-mingw32 --compiler gcc --buildtool both all)
[[ "$output" == *'--host=x86_64-w64-mingw32'* && "$output" == *'make install'* && "$output" == *'cmake --install'* ]]
[[ $(grep -c 'toolset=gcc-mingw target-os=windows' <<<"$output") = 1 ]]
output=$(check_flow linux --dry-run --target x86_64-w64-mingw32 --compiler gcc --buildtool configure --debug false wxwidgets)
[[ "$output" == *'--disable-debug'* && "$output" == *'/windows/wxwidgets/configure/mingw/'* ]]
echo "Bash flow checks passed."
