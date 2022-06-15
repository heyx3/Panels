"
A Panels session, including one main SDL window/renderer.

It is highly recommended to use the `@session` macro to define sessions.

Session types must be mutable, and have the following fields:
* `window::SDL_Window`
* `renderer::SDL_Renderer`
* `free_type::FT_Library` (convenient reference to `Panels.FREE_TYPE[]`)
* `quit_now::Bool` (a flag you can set to indicate that the session should end)
"
abstract type AbstractSession end


###   Interface   ###

# It's recommended to use `@session` instead of manually implementing this interface.


"Creates a session's SDL window, and returns its handle."
session_make_window(::AbstractSession) = SDL_CreateWindow(
    "Main Window",
    SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
    800, 550,
    SDL_WINDOW_SHOWN
)
"Creates a session's SDL renderer, after its window."
session_make_renderer(s::AbstractSession) = SDL_CreateRenderer(
    s.window, -1,
    SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC
)
"Starts the session."
session_init(::AbstractSession) = nothing

"Processes a window/OS event. Note that 'quit' events are handled separately."
session_event(::AbstractSession, ::SDL_Event) = nothing
"Updates the session, given the elapsed time since the last tick."
session_tick(::AbstractSession, delta_seconds::Float64) = nothing
"
Called at the end of a frame. By default, waits until a full 1/60 second has passed.
This helps prevent the session from running too quickly, burning CPU cycles.
"
session_frame_wait(::AbstractSession, delta_seconds::Float64) = begin
    leftover_frame_seconds = (1/60) - delta_seconds
    if leftover_frame_seconds > 0
        SDL_Delay(Int(floor(leftover_frame_seconds * 1000)))
    end
end

"
Called when the user wants to quit (e.x. clicks the 'X' on the window).
Returns whether the program should immediately exit.
If you want to delay exit, set your session's `quit_now` field.
"
session_quitting(::AbstractSession, event::SDL_Event) = true
"
Called just before the session is closed, the SDL window is destroyed, etc.
Note that this is *not* called if `session_init()` throws an error.
"
session_cleanup(::AbstractSession) = nothing


###   Utilities   ###


"Runs the given session instance."
function run_session(session::AbstractSession)
    # Set up the session's components.
    @assert(IS_INITIALIZED[], "Dependencies haven't been initialiized yet!")
    session.free_type = FREE_TYPE[]
    session.window = session_make_window(session)
    session.renderer = session_make_renderer(session)
    session.quit_now = false

    # Set up timing.
    last_time = Ref(time_ns())
    function update_time(last_time_ref)
        new_time = time_ns()
        elapsed_time = new_time - last_time_ref[]

        last_time_ref[] = new_time
        return elapsed_time / 1e9
    end

    # Run the loop.
    session_init(session)
    try
        last_event = Ref{SDL_Event}()
        while !session.quit_now
            # Process windows/OS events.
            while Bool(SDL_PollEvent(last_event))
                if last_event[].type == SDL_QUIT
                    if session_quitting(session, last_event[])
                        return nothing
                    end
                else
                    session_event(session, last_event[])
                end
            end

            # Tick.
            SDL_SetRenderDrawColor(session.renderer, 0, 0, 0, SDL_ALPHA_OPAQUE)
            SDL_RenderClear(session.renderer)
            elapsed = update_time(last_time)
            session_tick(session, elapsed)
            SDL_RenderPresent(session.renderer)
            session_frame_wait(session, elapsed)
        end
    finally
        session_cleanup(session)
        SDL_DestroyRenderer(session.renderer)
        SDL_DestroyWindow(session.window)
    end
end


"
Defines a new `AbstractSession`.
"
macro session()
    return quote
        
    end
end