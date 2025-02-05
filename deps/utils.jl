using StringEncodings
using UrlDownload
using Unitful
using StaticArrays
import Unitful: Length, Temperature, Quantity, Units
import ZipFile

function load_glass_db(directory::String)
    glass_catalog = Dict{String,Dict}()
    for path in readdir(directory)
        if uppercase(splitext(path)[2]) == ".AGF"
            parse_glass_file!(glass_catalog, joinpath(directory, path))
        end
    end
    return glass_catalog
end

function generate_cat_jl(cat, jlpath)
    catalogs = []
    io = open(jlpath, "w")
    idnum = 1
    glassnames = []
    for nameandcatalog in cat
        catalog_name, catalog = nameandcatalog
        push!(catalogs, catalog_name)
        eval_string = ["module $catalog_name"]
        push!(eval_string, "using ..GlassCat: Glass, GlassID, AGF")
        push!(eval_string, "using StaticArrays: SVector")
        for x in catalog
            let N = 0
                glass_name, glass_info = x
                push!(glassnames, "$catalog_name.$glass_name")
                vals = []
                for fn in string.(fieldnames(Glass))
                    if fn == "ID"
                        push!(vals, "GlassID(AGF, $idnum)")
                    elseif fn in ["D₀", "D₁", "D₂", "E₀", "E₁", "λₜₖ"]
                        push!(vals, repr(get(glass_info, fn, 0.0)))
                    elseif fn == "temp"
                        push!(vals, repr(get(glass_info, fn, 20.0)))
                    elseif fn == "transmission"
                        v = get(glass_info, "transmission", nothing)
                        if isnothing(v)
                            push!(vals, repr(nothing))
                        else
                            str = join(["($(join(a, ", ")))" for a in v], ", ")
                            push!(vals, "[$str]")
                        end
                    elseif fn == "transmissionN"
                        continue
                    else
                        push!(vals, repr(get(glass_info, fn, NaN)))
                    end
                end
                raw_name = glass_info["raw_name"] == glass_name ? "" : " ($(glass_info["raw_name"]))"
                doc_string = "\"\"\"    $catalog_name.$glass_name$raw_name\n"
                doc_string *= "```\n$(rpad("ID:", 25))AGF:$idnum\n"
                doc_string *= "$(rpad("RI @ 587nm:", 25))$(get(glass_info, "Nd", 0.0))\n"
                doc_string *= "$(rpad("Abbe Number:", 25))$(get(glass_info, "Vd", 0.0))\n"
                doc_string *= "$(rpad("ΔPgF:", 25))$(get(glass_info, "ΔPgF", 0.0))\n"
                doc_string *= "$(rpad("TCE (÷1e-6):", 25))$(get(glass_info, "TCE", 0.0))\n"
                doc_string *= "$(rpad("Density:", 25))$(get(glass_info, "p", 0.0))g/m³\n"
                doc_string *= "$(rpad("Valid wavelengths:", 25))$(get(glass_info, "λmin", 0.0))μm to $(get(glass_info, "λmax", 0.0))μm\n"
                doc_string *= "$(rpad("Reference Temp:", 25))$(get(glass_info, "temp", 20.0))°C\n"
                doc_string *= "```\n\"\"\""
                push!(eval_string, doc_string)
                push!(eval_string, "const $glass_name = Glass($(join(vals, ", "))) \n export $glass_name")
            end
            idnum += 1
        end
        push!(eval_string, "end #module \n export $catalog_name \n") # module
        eval_string = join(eval_string, "\n")
        write(io, eval_string * "\n")
    end
    write(io, "const AGF_GLASS_NAMES = [$(join(repr.(glassnames), ", "))]\n")
    write(io, "const AGF_GLASSES = [$(join(glassnames, ", "))]\n")
    close(io)
end

"""This function will download glass catalogs from publicly available sources and extract them to glassdirectory.  You can execute this in the Julia repl or run it as a Julia script from the command line. If you do the latter then cd to the GlassCat directory and enter this at the command line: julia "src/DownloadGlasses.jl" "path to the directory where you want your glass files stored". Schott, Sumita, and NHG have publicly available glass catalogs but you will have to manually download them and extract them to the GlassFiles directory."""
function downloadcatalogs(glassdirectory::String)
    catalogs = ("https://www.nikon.com/products/optical-glass/assets/pdf/nikon_zemax_data.zip", 
   # "http://hbnhg.com/down/data/nhgagp.zip", #this zip file has invalid UTF-8 characters in one of the files contained within it which causes ZipFile to crash. There are two files in the zip, one of which has wacky characters in its filename (perhaps Chinese) so you will have to manually extract just the one with the non-wacky characters to the GlassFiles directory.
    "https://www.oharacorp.com/xls/OHARA_201130_CATALOG.zip", 
    "https://hoyaoptics.com/wp-content/uploads/2019/10/HOYA20170401.zip",
    "https://www.schott.com/d/advanced_optics/6959f9a4-0e4f-4ef2-a302-2347468a82f5/1.31/schott-optical-glass-overview-zemax-format.zip")
    # can't download directly have to click on box https://www.sumita-opt.co.jp/en/download/
    # can't download directly have to click on selection https://www.schott.com/advanced_optics/english/download/index.html

    getzip(url)  = urldownload(url,compress = :zip, parser = identity)

    function writeglassfile(url,filename::String)
        try
            zipcat = getzip(url)
            # filename = replace(zipcat.name, r"""[ ,.:;?!()&-]""" => "_")
            # filename = replace(filename, "_agf" => ".agf")
            # filename = replace(filename, "_AGF" => ".agf")
            catname = joinpath(glassdirectory,filename)

            @info "reading $filename from web"
            temp = ZipFile.read(zipcat,String)

            @info "writing $filename to $catname"
            write(joinpath(glassdirectory,filename),temp)
        catch err
            @info "Couldn't download $url"
        end
    end

    #write the glass files with standard names so the examples in OpticSim.jl will work
    writeglassfile(catalogs[1],"NIKON.agf")
    writeglassfile(catalogs[2],"OHARA.agf")
    writeglassfile(catalogs[3],"HOYA.agf")
    writeglassfile(catalogs[4],"SCHOTT.agf")
end

function string_list_to_float_list(x)
    npts = length(x)
    if (npts == 0) || ((npts == 1) && (strip(x[1]) == "-"))
        return (repeat([-1.0], 10))
    end
    res = []
    for a in x
        if (strip(a) == "-")
            push!(res, -1.0)
        else
            try
                push!(res, parse(Float64, a))
            catch
                push!(res, NaN)
            end
        end
    end
    return (res)
end

function parse_glass_file!(glass_catalog, filename::String)
    if !isfile(filename)
        throw(error("AGF file doesn't exist"))
    end
    catalog_name = splitext(basename(filename))[1]
    # remove invalid characters
    catalog_name = replace(catalog_name, r"""[ ,.:;?!()&-]""" => "_")
    try
        # cant have module names which are just numbers so add a _ to the start
        parse(Int, catalog_name[1])
        catalog_name = "_" * catalog_name
    catch
        ()
    end
    glass_catalog[catalog_name] = Dict{String,Any}()
    # check whether the file is UTF8 or UTF16 encoded
    if !isvalid(readuntil(filename, " "))
        fo = open(filename, enc"UTF-16LE", "r")
    else
        fo = open(filename, "r")
    end
    # read the file
    glass_name = ""
    let transmission_data = nothing
        for line in readlines(fo)
            if strip(line) == "" || length(strip(line)) == 0 || startswith(line, "CC ") || startswith(line, "GC ")
                continue
            end
            if startswith(line, "NM ")
                transmission_data = Vector{SVector{3,Float64}}(undef, 0)
                nm = split(line)
                glass_name = nm[2]
                original_glass_name = glass_name
                # remove invalid characters
                glass_name = replace(glass_name, "*" => "_STAR")
                glass_name = replace(glass_name, r"""[ ,.:;?!()&-]""" => "_")
                try
                    # cant have module names which are just numbers so add a _ to the start
                    parse(Int, glass_name[1])
                    glass_name = "_" * glass_name
                catch
                    ()
                end
                glass_catalog[catalog_name][glass_name] = Dict{String,Any}()
                glass_catalog[catalog_name][glass_name]["raw_name"] = original_glass_name
                glass_catalog[catalog_name][glass_name]["dispform"] = Int(parse(Float64, nm[3]))
                glass_catalog[catalog_name][glass_name]["Nd"] = parse(Float64, nm[5])
                glass_catalog[catalog_name][glass_name]["Vd"] = parse(Float64, nm[6])
                if length(nm) < 7
                    glass_catalog[catalog_name][glass_name]["exclude_sub"] = 0
                else
                    glass_catalog[catalog_name][glass_name]["exclude_sub"] = Int(parse(Float64, nm[7]))
                end
                if length(nm) < 8
                    glass_catalog[catalog_name][glass_name]["status"] = 0
                else
                    glass_catalog[catalog_name][glass_name]["status"] = Int(parse(Float64, nm[8]))
                end
                if length(nm) < 9 || "-" ∈ nm
                    glass_catalog[catalog_name][glass_name]["meltfreq"] = 0
                else
                    glass_catalog[catalog_name][glass_name]["meltfreq"] = Int(parse(Float64, nm[9]))
                end
            elseif startswith(line, "ED ")
                ed = split(line)
                glass_catalog[catalog_name][glass_name]["TCE"] = parse(Float64, ed[2])
                glass_catalog[catalog_name][glass_name]["p"] = parse(Float64, ed[4])
                glass_catalog[catalog_name][glass_name]["ΔPgF"] = parse(Float64, ed[5])
                if (length(ed) < 6)
                    glass_catalog[catalog_name][glass_name]["ignore_thermal_exp"] = 0
                else
                    glass_catalog[catalog_name][glass_name]["ignore_thermal_exp"] = Int(parse(Float64, ed[6]))
                end
            elseif startswith(line, "CD ")
                cd = parse.(Float64, split(line)[2:end])
                glass_catalog[catalog_name][glass_name]["C1"] = get(cd, 1, NaN)
                glass_catalog[catalog_name][glass_name]["C2"] = get(cd, 2, NaN)
                glass_catalog[catalog_name][glass_name]["C3"] = get(cd, 3, NaN)
                glass_catalog[catalog_name][glass_name]["C4"] = get(cd, 4, NaN)
                glass_catalog[catalog_name][glass_name]["C5"] = get(cd, 5, NaN)
                glass_catalog[catalog_name][glass_name]["C6"] = get(cd, 6, NaN)
                glass_catalog[catalog_name][glass_name]["C7"] = get(cd, 7, NaN)
                glass_catalog[catalog_name][glass_name]["C8"] = get(cd, 8, NaN)
                glass_catalog[catalog_name][glass_name]["C9"] = get(cd, 9, NaN)
                glass_catalog[catalog_name][glass_name]["C10"] = get(cd, 10, NaN)
            elseif startswith(line, "TD ")
                td = parse.(Float64, split(line)[2:end])
                glass_catalog[catalog_name][glass_name]["D₀"] = get(td, 1, 0.0)
                glass_catalog[catalog_name][glass_name]["D₁"] = get(td, 2, 0.0)
                glass_catalog[catalog_name][glass_name]["D₂"] = get(td, 3, 0.0)
                glass_catalog[catalog_name][glass_name]["E₀"] = get(td, 4, 0.0)
                glass_catalog[catalog_name][glass_name]["E₁"] = get(td, 5, 0.0)
                glass_catalog[catalog_name][glass_name]["λₜₖ"] = get(td, 6, 0.0)
                glass_catalog[catalog_name][glass_name]["temp"] = get(td, 7, 20.0)
            elseif startswith(line, "OD ")
                od = string_list_to_float_list(split(line)[2:end])
                glass_catalog[catalog_name][glass_name]["relcost"] = get(od, 1, -1)
                glass_catalog[catalog_name][glass_name]["CR"] = get(od, 2, -1)
                glass_catalog[catalog_name][glass_name]["FR"] = get(od, 3, -1)
                glass_catalog[catalog_name][glass_name]["SR"] = get(od, 4, -1)
                glass_catalog[catalog_name][glass_name]["AR"] = get(od, 5, -1)
                glass_catalog[catalog_name][glass_name]["PR"] = get(od, 6, -1)
            elseif startswith(line, "LD ")
                ld = parse.(Float64, split(line)[2:end])
                glass_catalog[catalog_name][glass_name]["λmin"] = ld[1]
                glass_catalog[catalog_name][glass_name]["λmax"] = ld[2]
            elseif startswith(line, "IT ")
                it_row = parse.(Float64, split(line)[2:end])
                if length(it_row) == 3 && it_row[1] != 0.0
                    entry = SVector{3,Float64}(it_row[1], it_row[2], it_row[3])
                    push!(transmission_data, entry)
                end
                glass_catalog[catalog_name][glass_name]["transmission"] = transmission_data
            end
        end
    end
end
