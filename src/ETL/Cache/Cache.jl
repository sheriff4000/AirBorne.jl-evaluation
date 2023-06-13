"""
    This modules centralizes caching for the AirBorne package. Containing:
    - Definition of data storage procedures
    - Definition of data storage formats
"""
module Cache
using DataFrames: DataFrames
using Parquet2: Parquet2
using Dates: Dates

export hello_cache
export get_cache_path
export store_bundle
export load_bundle
export list_bundles

# TODO: 
# - Add method to list archive (Best practice will be to enabled an optional keyword on list_bundle)
# - Add method to load archive (Best practice will be to enabled an optional keyword on load_bundle) 

"""
    hello_cache()

Returns a string saying "Hello Cache!".
"""
function hello_cache()
    return "Hello Cache!"
end

"""
    gen_id()

    Generates an id based on the current UTC timestamp with format "yyyy_mm_dd_H_M_S_s"
"""
function gen_id()
    return Dates.format(Dates.now(Dates.UTC), "yyyy_mm_dd_H_M_S_s")
end

"""
     get_cache_path()
    
    Defines the cache path depending on the OS and environment variables.
    ```julia
    julia> import AirBorne
    julia> AirBorne.ETL.Cache.get_cache_path()
    ```
"""
function get_cache_path()
    cache_path = get(ENV, "AIRBORNE_ROOT", nothing)
    if !(isnothing(cache_path))
        return cache_path
    elseif (Sys.islinux()) || (Sys.isapple())
        return "/root/tmp/.AirBorne/.cache"
    elseif Sys.iswindows()
        return "$(ENV["HOME"])/.AirBorne/.cache"
    end
end

"""
    store_bundle(data::DataFrames.DataFrame; bundle_id::Union{Nothing, String}=nothing, archive::Bool=true, meta::Dict=Dict(), c_meta::Dict=Dict())
    
    Stores a dataframe in a bundle in parquet format.

    **Is very important that none of the columns are of type "Any"** as the storage for this column type is not defined.
"""
function store_bundle(
    data::DataFrames.DataFrame;
    bundle_id::Union{Nothing,String}=nothing,
    archive::Bool=true,
    meta::Dict=Dict(),
    c_meta::Dict=Dict(),
)
    # Define directories
    cache_dir = get_cache_path()
    bundle_id = !(isnothing(bundle_id)) ? bundle_id : gen_id()
    bundle_dir = joinpath(cache_dir, bundle_id)
    archive_dir = joinpath(bundle_dir, "archive")

    # Ensure directories exist
    if !(isdir(archive_dir))
        mkpath(archive_dir)
    end

    # Move current contents to archive
    contents = readdir(bundle_dir)
    files_to_archive = [c for c in contents if c != "archive"]
    for files_to_archive in files_to_archive
        if archive
            mv(
                joinpath(bundle_dir, files_to_archive),
                joinpath(archive_dir, files_to_archive),
            )
        else
            @info("Removing $(joinpath( bundle_dir,files_to_archive))")
            rm(joinpath(bundle_dir, files_to_archive))
        end
    end

    # Write file
    file_path = joinpath(bundle_dir, gen_id() * ".parq.snappy")

    @info("Storing $file_path")
    return Parquet2.writefile(
        file_path, data; compression_codec=:snappy, metadata=meta, column_metadata=c_meta
    )
end

"""
    load_bundle(bundle_id::String)

    Loads data from a cached bundle.
    
    # Returns
    DataFrames.DataFrame
"""
function load_bundle(bundle_id::String; cache_dir::Union{String,Nothing}=nothing)
    cache_dir = isnothing(cache_dir) ? get_cache_path() : cache_dir
    bundle_dir = joinpath(cache_dir, bundle_id)
    if !(isdir(bundle_dir))
        throw(ErrorException("Bundle does not exist."))
    end
    contents = readdir(bundle_dir)
    contents_to_read = [c for c in contents if c != "archive"]
    if size(contents_to_read)[1] != 1
        throw(
            ErrorException("$(size(contents_to_read)[1]) files found in bundle directory.")
        )
    end
    file_path = joinpath(bundle_dir, contents_to_read[1])
    ds = Parquet2.Dataset(file_path) # Create a dataset
    df = DataFrames.DataFrame(ds; copycols=false) # Load from dataframed
    return df
end

"""
    list_bundles()

    Returns the list of bundles available in the cached folder.
    
    In the future this function can be expanded to return information as timestamp, 
    format of data in bundle among relevant metadata.
"""
function list_bundles()
    return readdir(get_cache_path(); sort=false)
end

"""
    remove_bundle(bundle_id::String; just_archive::Bool=false)

    Removes bundle from cache. This is an irreversible operation. If just_archive is true it only flushes the archive folder.
"""
function remove_bundle(bundle_id::String; just_archive::Bool=false)
    # Define directories
    cache_dir = get_cache_path()
    bundle_dir = joinpath(cache_dir, bundle_id)
    archive_dir = joinpath(bundle_dir, "archive")
    if (just_archive) && (isdir(archive_dir))
        rm(archive_dir; recursive=true)
    elseif !(just_archive) && (isdir(bundle_dir))
        rm(bundle_dir; recursive=true)
    end
end

end
