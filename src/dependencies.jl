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

            FT_Done_FreeType(FREE_TYPE[])
            FREE_TYPE[] = C_NULL

            IS_INITIALIZED[] = false
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

"
Loads a font glyph, and converts it into an SDL texture (ARGB, 4 bits per channel).
You are responsible for destroying this texture when you're done with it.
"
function render_char( font_face::FT_Face, char::Char,
                      sdl_renderer::Ptr{SDL_Renderer}
                      ;
                      tex_access::SDL_TextureAccess = SDL_TEXTUREACCESS_STATIC
                    )::Ptr{SDL_Texture}
    # Load the char as a bitmap.
    code = FT_Load_Char(font_face, char, FT_LOAD_RENDER)
    if code != FT_Err_Ok
        error("Couldn't load font char '", char, "': ", code)
    end
    bitmap::FT_Bitmap = unsafe_load(unsafe_load(font_face).glyph).bitmap

    # Create a texture to hold the rendered char.
    tex::Ptr{SDL_Texture} = SDL_CreateTexture(
        sdl_renderer,
        SDL_PIXELFORMAT_ARGB8888, tex_access,
        bitmap.width, bitmap.rows
    )
    if tex == C_NULL
        error("Couldn't create SDL texture: ", unsafe_string(SDL_GetError()))
    end

    # Write the bitmap's pixels into the texture.
    pixel_data = Matrix{UInt32}(undef, (bitmap.width, bitmap.rows))
    for y in 1:bitmap.rows
        for x in 1:bitmap.width
            pixel::UInt8 = unsafe_load(bitmap.buffer, x + (y * bitmap.pitch))
            pixel_data[x, y] = (UInt32(pixel)) | (UInt32(pixel) << 8) | (UInt32(pixel) << 16) |
                               ((pixel > 0) ? 0xFF000000 : 0x00000000)
        end
    end
    SDL_UpdateTexture(tex, C_NULL, pixel_data,
                      bitmap.width * sizeof(eltype(pixel_data)))

    return tex
end