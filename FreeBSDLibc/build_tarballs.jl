using BinaryBuilder

name = "FreeBSDLibc"
version = v"11.1"

# sources to build, such as mingw32, our patches, etc....
sources = [
    "https://download.freebsd.org/ftp/releases/amd64/11.1-RELEASE/base.txz" =>
    "62acaee7e7c9df66ee2c0c2d533d1da0ddf67d32833bc4b77d935ddd9fe27dab"
]

# Bash recipe for building across all platforms
script = raw"""
cd $WORKSPACE/srcdir
sysroot="${prefix}/${target}/sys-root"

# We're going to clean out vestiges of libgcc_s and friends,
# because we're going to compile our own from scratch
for lib in gcc_s ssp; do
    find . -name lib${lib}.\* -delete
done

mkdir -p "${sysroot}/usr"
mv usr/lib "${sysroot}/usr/"
mv lib "${sysroot}/lib"

# Many symlinks exist that point to `../../lib/libfoo.so`.
# We need them to point to just `libfoo.so`. :P
for f in $(find "${prefix}/${target}" -xtype l); do
	link_target="$(readlink "$f")"
	if [[ -n $(echo "${link_target}" | grep "^../../lib") ]]; then
		ln -vsf "${link_target#../../lib/}" "${f}"
	fi
done
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = [
    FreeBSD(:x86_64),
]

# The products that we will ensure are always built
products(prefix) = [
    LibraryProduct(prefix, "libc", :libc),
]

# Dependencies that must be installed before this package can be built
dependencies = [
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies; skip_audit=true)
