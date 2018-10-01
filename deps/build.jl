using BinDeps

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
