using Panels

using Test, SimpleDirectMediaLayer.LibSDL2, FreeType


Base.@kwdef mutable struct TestSession <: Panels.AbstractSession
    window::Ptr{SDL_Window} = C_NULL
    renderer::Ptr{SDL_Renderer} = C_NULL
    free_type::FT_Library = C_NULL
    quit_now::Bool = false

    total_seconds::Float64 = 0.0
    font_face::FT_Face = C_NULL
end

function Panels.session_init(t::TestSession)
    t.font_face = Panels.make_face("$(@__DIR__)/FreeMonospaced-7ZXP.ttf", 64)
end
function Panels.session_event(t::TestSession, event::SDL_Event)
    if event.type == SDL_KEYDOWN
        t.quit_now = true
    end
end
function Panels.session_tick(t::TestSession, elapsed::Float64)
    t.total_seconds += elapsed

    SDL_SetRenderDrawColor(t.renderer, 255, 60, 255, SDL_ALPHA_OPAQUE)
    SDL_RenderDrawLine(t.renderer, 30, 30, 600, 400)

    #TODO: Draw a character
end

Panels.with_dependencies() do
    Panels.run_session(TestSession())
end