using SHA, BinaryBuilder
using BinaryBuilder: TarballDependency

function find_tarball(project, pattern)
    dir = joinpath("..", project, "products")
    if !isdir(dir)
        error("No $(project)/products directory?!")
    end

    pattern = Regex(".*$(pattern).*\\.tar\\.gz")
    for f in readdir(dir)
        if match(pattern, f) !== nothing
            path = abspath(joinpath(dir, f))
            hash = open(path, "r") do io
                return bytes2hex(sha256(io))
            end
            return TarballDependency(path, hash)
        end
    end
    error("Could not find $(project) tarball matching $(pattern)!")
end
