#include "Algorithm.h"
#include "napi/native_api.h"

/**
 * NAPI interface: Convert pitch value to tone value
 */
static napi_value PitchToTone(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};

    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc != 1) {
        napi_throw_error(env, nullptr, "Wrong number of arguments. Expected 1.");
        return nullptr;
    }

    napi_valuetype valuetype;
    napi_typeof(env, args[0], &valuetype);

    if (valuetype != napi_number) {
        napi_throw_type_error(env, nullptr, "Wrong argument type. Expected number.");
        return nullptr;
    }

    double pitch;
    napi_get_value_double(env, args[0], &pitch);

    double result = pitchToToneC(pitch);

    napi_value napi_result;
    napi_create_double(env, result, &napi_result);

    return napi_result;
}

/**
 * NAPI interface: Calculate score
 */
static napi_value CalculatedScore(napi_env env, napi_callback_info info) {
    size_t argc = 4;
    napi_value args[4] = {nullptr};

    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc != 4) {
        napi_throw_error(env, nullptr, "Wrong number of arguments. Expected 4.");
        return nullptr;
    }

    // Validate parameter types
    for (int i = 0; i < 4; i++) {
        napi_valuetype valuetype;
        napi_typeof(env, args[i], &valuetype);
        if (valuetype != napi_number) {
            napi_throw_type_error(env, nullptr, "Wrong argument type. Expected number.");
            return nullptr;
        }
    }

    double voicePitch, stdPitch;
    int32_t scoreLevel, scoreCompensationOffset;

    napi_get_value_double(env, args[0], &voicePitch);
    napi_get_value_double(env, args[1], &stdPitch);
    napi_get_value_int32(env, args[2], &scoreLevel);
    napi_get_value_int32(env, args[3], &scoreCompensationOffset);

    float result = calculatedScoreC(voicePitch, stdPitch, scoreLevel, scoreCompensationOffset);

    napi_value napi_result;
    napi_create_double(env, result, &napi_result);

    return napi_result;
}

/**
 * NAPI interface: Handle pitch compensation
 */
static napi_value HandlePitch(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3] = {nullptr};

    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc != 3) {
        napi_throw_error(env, nullptr, "Wrong number of arguments. Expected 3.");
        return nullptr;
    }

    // Validate parameter types
    for (int i = 0; i < 3; i++) {
        napi_valuetype valuetype;
        napi_typeof(env, args[i], &valuetype);
        if (valuetype != napi_number) {
            napi_throw_type_error(env, nullptr, "Wrong argument type. Expected number.");
            return nullptr;
        }
    }

    double stdPitch, voicePitch, stdMaxPitch;

    napi_get_value_double(env, args[0], &stdPitch);
    napi_get_value_double(env, args[1], &voicePitch);
    napi_get_value_double(env, args[2], &stdMaxPitch);

    double result = handlePitchC(stdPitch, voicePitch, stdMaxPitch);

    napi_value napi_result;
    napi_create_double(env, result, &napi_result);

    return napi_result;
}

/**
 * NAPI interface: Reset algorithm state
 */
static napi_value Reset(napi_env env, napi_callback_info info) {
    resetC();

    napi_value result;
    napi_get_undefined(env, &result);
    return result;
}

/**
 * Keep the original Add function as an example
 */
static napi_value Add(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2] = {nullptr};

    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    napi_valuetype valuetype0;
    napi_typeof(env, args[0], &valuetype0);

    napi_valuetype valuetype1;
    napi_typeof(env, args[1], &valuetype1);

    double value0;
    napi_get_value_double(env, args[0], &value0);

    double value1;
    napi_get_value_double(env, args[1], &value1);

    napi_value sum;
    napi_create_double(env, value0 + value1, &sum);

    return sum;
}

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        {"add", nullptr, Add, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"pitchToTone", nullptr, PitchToTone, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"calculatedScore", nullptr, CalculatedScore, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"handlePitch", nullptr, HandlePitch, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"reset", nullptr, Reset, nullptr, nullptr, nullptr, napi_default, nullptr}};
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}
EXTERN_C_END

static napi_module demoModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "lyrics_view",
    .nm_priv = ((void *)0),
    .reserved = {0},
};

extern "C" __attribute__((constructor)) void RegisterLyrics_viewModule(void) { napi_module_register(&demoModule); }
