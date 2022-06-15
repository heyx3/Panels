using SimpleDirectMediaLayer.LibSDL2
using FreeType


###   Constants   ###

"Whether dependencies have been initialized yet."
const IS_INITIALIZED = Ref{Bool}(false)

"The FreeType library, assuming dependencies have been initialized."
const FREE_TYPE = Ref{FT_Library}(C_NULL)


###   Implementation   ###

"Used for thread-safe initialization of dependencies."
const INITIALIZATION_MUTEX = ReentrantLock()


"Starts up SDL, FreeType, etc."
function init_dependencies(sdl_flags = SDL_INIT_EVERYTHING)
    lock(INITIALIZATION_MUTEX) do
        @assert(!IS_INITIALIZED[], "Initialization has happened already")

        # Initialize SDL.
        result_code_sdl = SDL_Init(sdl_flags)
        if result_code_sdl != 0
            error("SDL error on startup (", result_code_sdl, "): ", unsafe_string(SDL_GetError()))
        end

        # Initialize FreeType.
        free_type_ref = Ref{FT_Library}()
        result_code_ft = FT_Init_FreeType(FREE_TYPE)
        if result_code_ft != FT_Err_Ok
            FREE_TYPE[] = C_NULL
            error("FreeType error on startup: ", result_code_ft)
        end

        IS_INITIALIZED[] = true
    end
end
"Closes SDL, FreeType, etc."
function close_dependencies()
    lock(INITIALIZATION_MUTEX) do
        if IS_INITIALIZED[]
            SDL_Quit()

            # Apparently FreeType does not need to be cleaned up?
            FREE_TYPE[] = C_NULL
        end
    end
end


###   Interface   ###

function with_dependencies(to_do, sdl_flags = nothing)
    if isnothing(sdl_flags)
        init_dependencies()
    else
        init_dependencies(sdl_flags)
    end
    try
        to_do()
    finally
        close_dependencies()
    end
end


"Loads a font face using FreeType, with some basic settings."
function make_face( font_file_path::AbstractString,
                    size::Union{Int, NTuple{2, Int}}
                    ;
                    library::FT_Library = FREE_TYPE[],
                    file_index::Int = 0
                  )::FT_Face
    # Create the face.
    face = Ref{FT_Face}()
    error_code = FT_New_Face(library, font_file_path, file_index, face)
    if error_code != FT_Err_Ok
        error("FreeType face creation error (FT_New_Face): ", error_code)
    end

    # Configure the face's size.
    if size isa Int
        size = (size, size)
    end
    error_code = FT_Set_Pixel_Sizes(face[], size...)
    if error_code != FT_Err_Ok
        error("Freetype face sizing error (FT_Set_Pixel_Sizes): ", error_code)
    end

    return face[]
end