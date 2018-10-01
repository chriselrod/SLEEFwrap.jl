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
if register_size == 8
    vector_sizes_string = """
    const SIZES = Tuple{DataType,Symbol,Symbol}[
        (Float64, Symbol(), Symbol()),
        (Float32, :f, Symbol())
    ]
    """
elseif register_size == 16
    vector_sizes_string = """
    const SIZES = Tuple{DataType,Symbol,Symbol}[
        (Float64, Symbol(), Symbol()),
        (Float32, :f, Symbol()),
        (__m128d, :d2, :avx2128),
        (__m128,  :f4, :avx2128)
    ]
    """
elseif register_size == 32
    vector_sizes_string = """
    const SIZES = Tuple{DataType,Symbol,Symbol}[
        (Float64, Symbol(), Symbol()),
        (Float32, :f, Symbol()),
        (__m128d, :d2, :avx2128),
        (__m128,  :f4, :avx2128),
        (__m256d, :d4, :avx2),
        (__m256,  :f8, :avx2)
    ]
    """
elseif register_size == 64
    vector_sizes_string = """
    const SIZES = Tuple{DataType,Symbol,Symbol}[
        (Float64, Symbol(), Symbol()),
        (Float32, :f, Symbol()),
        (__m128d, :d2, :avx2128),
        (__m128,  :f4, :avx2128),
        (__m256d, :d4, :avx2),
        (__m256,  :f8, :avx2),
        (__m256d, :d8, :avx512f),
        (__m256,  :f16,:avx512f)
    ]
    """

else
    throw("Register size $register_size is not supported.")
end


open(joinpath(@__DIR__, "..", "src", "vector_sizes.jl"), "w") do f
    write(f, vector_sizes_string)
end
