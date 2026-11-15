function value = jsValue(script, state)
arguments (Input)
    script
    state
end

arguments (Output)
    value (3,1)
end

args = sprintf(' %.17g', state);
[status, out] = system(['node "' script '"' args]);

if status ~= 0
    error('jsValue:nodeFailed', '%s', out);
end

value = sscanf(out, '%f');
end
