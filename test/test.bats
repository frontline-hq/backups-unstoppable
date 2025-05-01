export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
source "${PROJECT_ROOT}/src/scripts/common.sh"

setup_file() {
    setup_environment --detach
}

teardown_file() {
    teardown_environment
}

# Dynamically register tests for each subdirectory in /vars/test
for dir in "${PROJECT_ROOT}/vars/test/"*; do
    if [ -d "$dir" ]; then
        bats_test_function --description "Test in ./$(basename $dir): ${TEST_NAME}" \
            -- run_test "$dir"
    fi
done
