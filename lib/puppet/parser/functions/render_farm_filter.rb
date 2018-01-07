module Puppet
  module Parser
    module Functions
      newfunction(:render_farm_filter, type: :rvalue, doc:<<-DOC
Render a farm filter entry.
Will check if it needs to render regex with single quote or regular strings with double quotes.
@param filter [String] Filter string to render
@return [String] Regex or regular string farm entry
@example Rendering globs
  render_farm_filter("*")
@example Rendering regex
  render_farm_filter("'(content|apps).*'")
DOC
        ) do |args|
        # Validate input
        unless args.length == 1
          raise Puppet::ArgumentError, "render_farm_filter() wrong number of arguments (#{args.length}; must be 1)"
        end

        unless args[0].is_a?(String)
          raise Puppet::ArgumentError, 'render_farm_filter() argument should be an string.'
        end

        return args[0] if args[0].start_with?("'") && args[0].end_with?("'")
        return '"' + args[0] + '"'
      end
    end
  end
end
