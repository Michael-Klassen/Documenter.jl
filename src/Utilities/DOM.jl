module DOM

using Compat

const BLOCK_ELEMENTS = Set([
    :address, :article, :aside, :blockquote, :canvas, :dd, :div, :dl,
    :fieldset, :figcaption, :figure, :footer, :form, :h1, :h2, :h3, :h4, :h5,
    :h6, :header, :hgroup, :hr, :li, :main, :nav, :noscript, :ol, :output, :p,
    :pre, :section, :table, :tfoot, :ul, :video,
])
const INLINE_ELEMENTS = Set([
    :a, :abbr, :acronym, :b, :bdo, :big, :br, :button, :cite, :code, :dfn, :em,
    :i, :img, :input, :kbd, :label, :map, :object, :q, :samp, :script, :select,
    :small, :span, :strong, :sub, :sup, :textarea, :time, :tt, :var,
])
const VOID_ELEMENTS = Set([
    :area, :base, :br, :col, :command, :embed, :hr, :img, :input, :keygen,
    :link, :meta, :param, :source, :track, :wbr,
])
const ALL_ELEMENTS = union(BLOCK_ELEMENTS, INLINE_ELEMENTS, VOID_ELEMENTS)

const EMPTY_STRING = ""
const TEXT = Symbol(EMPTY_STRING)

immutable Tag
    name :: Symbol
end

Base.show(io::IO, t::Tag) = print(io, "<", t.name, ">")

macro tags(args...) esc(tags(args)) end
tags(s) = :(const ($(s...),) = $(map(Tag, s)))

typealias Attributes Vector{Pair{Symbol, String}}

immutable Node
    name :: Symbol
    text :: String
    attributes :: Attributes
    nodes :: Vector{Node}

    Node(name::Symbol, attr::Attributes, data::Vector{Node}) = new(name, EMPTY_STRING, attr, data)
    Node(text::AbstractString) = new(TEXT, text)
end

@compat (t::Tag)(args...) = Node(t.name, Attributes(), data(args))
@compat (n::Node)(args...) = Node(n.name, n.attributes, data(args))
Base.getindex(t::Tag, args...) = Node(t.name, attr(args), Node[])
Base.getindex(n::Node, args...) = Node(n.name, attr(args), n.nodes)

data(args) = flatten!(nodes!, Node[], args)
attr(args) = flatten!(attributes!, Attributes(), args)

typealias Atom Union{AbstractString, Node, Pair{Symbol, String}, Symbol}

flatten!(f!, out, x::Atom) = f!(out, x)
flatten!(f!, out, xs)      = (for x in xs; flatten!(f!, out, x); end; out)

nodes!(out, s::AbstractString) = push!(out, Node(s))
nodes!(out, n::Node)           = push!(out, n)

function attributes!(out, s::AbstractString)
    class, id = IOBuffer(), IOBuffer()
    for x in eachmatch(r"[#|\.]([\w\-]+)", s)
        print(startswith(x.match, '.') ? class : id, x.captures[1], ' ')
    end
    position(class) === 0 || push!(out, :class => rstrip(takebuf_string(class)))
    position(id)    === 0 || push!(out, :id    => rstrip(takebuf_string(id)))
    return out
end
attributes!(out, s::Symbol) = push!(out, s => "")
attributes!(out, p::Pair)   = push!(out, p)

function Base.show(io::IO, n::Node)
    if n.name === TEXT
        print(io, escapehtml(n.text))
    else
        print(io, '<', n.name)
        for (name, value) in n.attributes
            print(io, ' ', name)
            isempty(value) || print(io, '=', repr(value))
        end
        if n.name in VOID_ELEMENTS
            print(io, "/>")
        else
            print(io, '>')
            if n.name === :script || n.name === :style
                isempty(n.nodes) || print(io, n.nodes[1].text)
            else
                for each in n.nodes
                    show(io, each)
                end
            end
            print(io, "</", n.name, '>')
        end
    end
end

function escapehtml(text::AbstractString)
    if ismatch(r"[<>&'\"]", text)
        buffer = IOBuffer()
        for char in text
            char === '<'  ? write(buffer, "&lt;")   :
            char === '>'  ? write(buffer, "&gt;")   :
            char === '&'  ? write(buffer, "&amp;")  :
            char === '\'' ? write(buffer, "&#39;")  :
            char === '"'  ? write(buffer, "&quot;") : write(buffer, char)
        end
        takebuf_string(buffer)
    else
        text
    end
end

end

