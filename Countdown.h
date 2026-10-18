#pragma once
#include <cmath>
#include <cstdint>

// Display arithmetic only. Apple supplies the occurrence date.
// Ceil keeps a future occurrence from appearing to be due a second early.
static inline uint64_t FMMSeconds(double interval) {
    return std::isfinite(interval) && interval > 0 && interval < 1e12
        ? static_cast<uint64_t>(std::ceil(interval)) : 0;
}
