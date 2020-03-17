module PackagePublisher

    using Pkg, JSON3
    using HubCLI: Hub

    # repo points to git directory
    # project points to Project.toml

    Base.@kwdef mutable struct PublisherConfig
        CIName::String = "Test"
        CIFileName::String = "CI.yml"
        SSHSecretName::String = "SSH_private_access"
    end
    JSON3.StructType(::Type{PublisherConfig}) = JSON3.StructTypes.Mutable()
    const CONFIG = PublisherConfig()

    function __init__()
        loadconfig()
    end

    function loadconfig(path=joinpath(homedir(), ".julia", "config", "PackagePublisher.json"))
        isfile(path) && return JSON3.read
    end

    function saveconfig(path=joinpath(homedir(), ".julia", "config", "PackagePublisher.json"))
        !isfile(path) && mkpath(dirname(path))
        open(io->JSON3.write(io, CONFIG), "w")
    end

    function setconfig!(key, value; save=true)
        CONFIG[key] = value
        save && saveconfig()
    end

    # function fetchprojectdir(path)
    #     basename(path) == "Project.toml" && return dirname
    #     isdirpath(path) && return path # / as last char
    #     isfile(path) && return dirname(path) # path is an existing file -> no / as last char
    #     nextpath = joinpath(path, "Project.toml")
    #     isfile(nextpath) && return dirname(nextpath) # no / as last char
    #     isfile() && return
    #     #TODO unfinished. Where to normalize paths to base directory of package? What even is normalized? with or w/o / at end?
    # end

    # function publish!(world)
    #     proj = Pkg.Types.read_project(Pkg.Types.find_project_file())
    #     proj === nothing && error("Package must contain a Project.toml")
    #     publish!(world, proj)
    # end

    # function publish!(world, localrepo)
    #     checknotenv(localrepo) || error("Cannot publish an environment. Activate a package.")
    #     cipath = pathci(localrepo)
    #     missesci(cipath) && gh_setupci(cipath)
    #     # populate!(remote(world), localrepo)
    #     # register!(registry(world), localrepo)

    # end

    function add_github_ci(repo; login="id_rsa_testing")
        temporarycheckout(repo) do localrepo
            cd(localrepo)
            missesci(localrepo) && gh_setupci(localrepo, loginsecret=login)
            Hub.hub(:push)
        end
    end

    pathci(localrepo=Base.active_project()) = joinpath(dirname(localrepo),".github", "workflows", CONFIG[:CIFileName])

    function missesci(localrepo)
        checkpath(localrepo) && return false
        return isfile(pathci(localrepo))
    end

    function temporarycheckout(f, repo)
        mktempdir() do npath
            cd(npath) do
                _, err, _ = Hub.hub(:clone, repo)
                startswith(err, "Error") && (println(err); return)
                cd(match(r"Cloning into '([^']+)'...", err)[1])
                f(pwd())
                # _, err, _ = Hub.hub(:push, "--dry-run")
                # println(err)
            end
        end
    end

    function gh_setupci(localrepo; loginsecret)
        checkpath(localrepo) || error("Can only add CI to packages.")
        placetemplate!(localrepo)
        addbadge!(localrepo)
        gh_setup_testing_secrets!(gh_url(localrepo), localrepo, loginsecret)
        Hub.hub(:add, "*")
        Hub.hub(:commit, "-m", "add Github CI")
    end

    function gh_url(localrepo)

    end

    function placetemplate!(localrepo)
        cipath = pathci(localrepo)
        mkpath(dirname(cipath))
        template = read("CItemplate.yml", String)
        template = replace(template, "<CIName>"=>CONFIG[:CIName], "<Registries>"=>getregistriesforpackage(localrepo))
        write(cipath, template)
    end

    function getregistriesforpackage(localrepo)
        join((x.url for x in Pkg.Types.collect_registries()), " ")
    end

    function addbadge!(localpkg, origin)
        "![Test]($origin/workflows/Test/badge.svg)"
    end

    function gh_setup_testing_secrets!(remote_gh_url, localrepo; secretfile="id_rsa")
        keypath = startswith(secretfile, ".") ? secretfile : joinpath(homedir(), ".ssh", secretfile)
        secretkey = Base.SecretBuffer!(read(keypath))
        res = Hub.push_secret!(remote_gh_url, CONFIG[:SSHSecret]=>secretkey)
        Base.shred!(secretkey)
        return res
    end



    checkpath(package) = !occursin("environments", dirname(package)) && isfile(joinpath(package, "Project.toml"))

    function predictintendedproject(path::Union{Nothing, AbstractString}, pkgname::Union{Nothing, AbstractString})

    end

    function turnintopackage(;path::Union{Nothing, AbstractString}=nothing, pkgname::Union{Nothing, AbstractString}=nothing)
        error("not yet implemented")
        # proj = Pkg.Types.EnvCache()
        # projtoml = joinpath(dir, "Project.toml")
        # if isfile(projtoml)
        #     toml = Pkg.Types.
        # Pkg.Types.is
    end

    function register()
        error("not yet implemented")
    end
end
