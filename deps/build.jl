using BinDeps, CpuId

@BinDeps.setup

const VERSION = "3.3.1"

libsleef = library_dependency("libsleef")

provides(Sources, URI("https://github.com/shibatch/sleef/archive/$VERSION.tar.gz"), libsleef, unpacked_dir = "sleef-$VERSION")

sleefsrc = joinpath(@__DIR__, "src", "sleef-$VERSION")
builddir = joinpath(sleefsrc, "build")
prefix = joinpath(BinDeps.depsdir(libsleef), "usr")

provides(BuildProcess,
    (@build_steps begin
        GetSources(libsleef)
        @build_steps begin
            ChangeDirectory(sleefsrc)
            CreateDirectory(builddir)
            @build_steps begin
                ChangeDirectory(builddir)
                `cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_DFT=FALSE -DCMAKE_INSTALL_PREFIX=$prefix ..`
                `make -j$(1+Sys.CPU_THREADS)`
                `make install`
            end
        end
    end), libsleef)

@BinDeps.install Dict(:libsleef => :libsleef)

register_size = simdbytes()
latest_instruction_set = (Symbol(),Symbol(),Symbol())
instruction_sets = (
    (:SSE2, (:sse2,Symbol(),Symbol())),
    (:SSE41,(:sse4,Symbol(),Symbol())),
    (:AVX,(:sse4,:avx,Symbol())),
    (:FMA4,(:sse4,:fma4,Symbol())),
    (:AVX2,(:avx2128,:avx2,Symbol())),
    (:AVX512F,(:avx2128,:avx2,:avx512f))
)
for (instruction_set, instructions) ∈ instruction_sets
    CpuId.cpufeature(instruction_set) || continue
    global latest_instruction_set = instructions
end

if register_size == 8
    vector_sizes_string = """
    const REGISTER_SIZE = 8
    const REGISTER_COUNT = 8 # is this correct?
    const SIZES = [
        (Float64, Symbol(), Symbol()),
        (Float32, :f, Symbol())
    ]
    """
elseif register_size == 16
    vector_sizes_string = """
    const REGISTER_SIZE = 16
    const REGISTER_COUNT = 16
    const SIZES = [
        (Float64, Symbol(), Symbol()),
        (Float32, :f, Symbol()),
        (__m128d, :d2, :($(latest_instruction_set[1]))),
        (__m128,  :f4, :($(latest_instruction_set[1])))
    ]
    """
elseif register_size == 32
    vector_sizes_string = """
    const REGISTER_SIZE = 32
    const REGISTER_COUNT = 16
    const SIZES = [
        (Float64, Symbol(), Symbol()),
        (Float32, :f, Symbol()),
        (__m128d, :d2, :($(latest_instruction_set[1]))),
        (__m128,  :f4, :($(latest_instruction_set[1]))),
        (__m256d, :d4, :($(latest_instruction_set[2]))),
        (__m256,  :f8, :($(latest_instruction_set[2])))
    ]
    """
elseif register_size == 64
    vector_sizes_string = """
    const REGISTER_SIZE = 64
    const REGISTER_COUNT = 32
    const SIZES = [
        (Float64, Symbol(), Symbol()),
        (Float32, :f, Symbol()),
        (__m128d, :d2, :($(latest_instruction_set[1]))),
        (__m128,  :f4, :($(latest_instruction_set[1]))),
        (__m256d, :d4, :($(latest_instruction_set[2]))),
        (__m256,  :f8, :($(latest_instruction_set[2]))),
        (__m512d, :d8, :($(latest_instruction_set[3]))),
        (__m512,  :f16,:($(latest_instruction_set[3])))
    ]
    """

else
    throw("Register size $register_size is not supported.")
end


open(joinpath(@__DIR__, "..", "src", "vector_sizes.jl"), "w") do f
    write(f, vector_sizes_string)
end
