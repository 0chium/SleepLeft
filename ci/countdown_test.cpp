#include "../Countdown.h"
#include <cassert>
#include <limits>

int main() {
    assert(FMMSeconds(0.01) == 1);
    assert(FMMSeconds(1.0) == 1);
    assert(FMMSeconds(1.01) == 2);
    assert(FMMSeconds(3599.2) == 3600);
    assert(FMMSeconds(7 * 86400.0) == 604800);
    assert(FMMSeconds(0) == 0 && FMMSeconds(-1) == 0);
    assert(FMMSeconds(std::numeric_limits<double>::quiet_NaN()) == 0);
    assert(FMMSeconds(std::numeric_limits<double>::infinity()) == 0);
    assert(FMMSeconds(1e12) == 0);
    // Recompute from wall time: a delayed tick jumps straight to the right value.
    const double occurrence = 10000;
    assert(FMMSeconds(occurrence - 9990.2) == 10);
    assert(FMMSeconds(occurrence - 9994.7) == 6);
}
