#pragma once

#import <simd/simd.h>

// MARK: - Cross-environment macros

#if defined(__METAL_VERSION__)
#import <metal_stdlib>
#define ATTRIBUTE(INDEX) [[attribute(INDEX)]]
#define TEXTURE2D(TYPE, ACCESS) metal::texture2d<TYPE, ACCESS>
#define DEPTH2D(TYPE, ACCESS) metal::depth2d<TYPE, ACCESS>
#define TEXTURECUBE(TYPE, ACCESS) metal::texturecube<TYPE, ACCESS>
#define SAMPLER metal::sampler
#define BUFFER(ADDRESS_SPACE, TYPE) ADDRESS_SPACE TYPE
#else
#import <Metal/Metal.h>
#define ATTRIBUTE(INDEX)
#define TEXTURE2D(TYPE, ACCESS) MTLResourceID
#define DEPTH2D(TYPE, ACCESS) MTLResourceID
#define TEXTURECUBE(TYPE, ACCESS) MTLResourceID
#define SAMPLER MTLResourceID
#define BUFFER(ADDRESS_SPACE, TYPE) TYPE
#endif

// MARK: - Enum macros

// Copied from <CoreFoundation/CFAvailability.h>
#define __MS_ENUM_ATTRIBUTES __attribute__((enum_extensibility(open)))
#define __MS_ANON_ENUM(_type) enum __MS_ENUM_ATTRIBUTES : _type
#define __MS_NAMED_ENUM(_type, _name)                                                                                  \
    enum __MS_ENUM_ATTRIBUTES _name : _type _name;                                                                     \
    enum _name : _type
#define __MS_ENUM_GET_MACRO(_1, _2, NAME, ...) NAME
#define MS_ENUM(...) __MS_ENUM_GET_MACRO(__VA_ARGS__, __MS_NAMED_ENUM, __MS_ANON_ENUM, )(__VA_ARGS__)
