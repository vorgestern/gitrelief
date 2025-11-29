
local alltag=require "alltag"
local fpp=require "luafpp"

local conflict_styles={merge="merge", diff3="diff3", zdiff3="zdiff3"}

local function edproc(filename)
    local k=io.open(filename, "a")
    if not k then error(string.format("edproc: Kann %s nicht finden/anlegen.", filename)) end
    k:close()
    return function(commands)
        if not commands then return end
        local k=io.popen(string.format("ed -s \"%s\"", filename), "w")
        if not k then error(string.format("edproc \"%s\" .. fehlgeschlagen.", filename)) end
        k:write(commands)
        k:close()
    end
end

local function sink() end
local function gitexec(cmd) alltag.pipe_lines("git "..cmd, sink) end
local function gitprint(cmd) alltag.pipe_lines("git "..cmd, print) end
local function gitlines(cmd) local L={}; alltag.pipe_lines("git "..cmd, function(z) table.insert(L, z) end); return table.concat(L, "\n") end

local git={
    init=function(name) gitexec("init -q "..(name or "")) end,
    config=function(key, value)
        if value then gitexec("config "..key.." "..value) end
        return gitlines("config "..key)
    end,
    add=function(...) gitexec("add "..table.concat({...}, " ")) end,
    commit=function(message) gitexec(string.format("commit -m \"%s\"", message)) end,
    log=function(...) return gitlines "log" end,
    newbranch=function(name)
        if not name then error "git.branch: branchname missing" end
        gitlines("checkout -b "..name)
    end,
    checkout=function(name)
        if not name then error "git.checkout: branchname missing" end
        gitlines("checkout "..name)
    end,
    merge=function(name)
        if not name then error "git.merge: branchname missing" end
        gitexec("merge "..name)
    end,
    status=function() return gitlines "status --porcelain=v2" end,
    diff=function() return gitlines "diff" end,
}

local mkemptyfolder=function(name)
    if fpp.exists(name) and not (fpp.type(name) :match "D") then os.remove(name) end
    if not fpp.exists(name) then fpp.mkdir(name) end
    local X=fpp.walkdir(name, ".T")
    for j,k in ipairs(X) do
        -- print("rm", k.catpath, k.type)
        if k.type=="D" then fpp.rmrf(k.catpath)
        else os.remove(k.catpath)
        end
    end
end

local mergedemo=function(conflictstyle)
    local name="demo_"..conflictstyle
    mkemptyfolder(name)
    if true then
        fpp.cd(name)
        git.init()
        git.config("user.name", "relieftest")
        git.config("user.email", "test@relief")
        print("Verwende conflict style:", git.config("merge.conflictStyle", conflictstyle))

        local hoppla=edproc "hoppla.txt"

        hoppla "a\nZeile 1\nZeile 2\nZeile 3\n.\nw\nq\n"
        git.add "."
        git.commit "Start"

        git.newbranch "branch1"
        hoppla "a\nAdd line in branch 1.\n.\n2\nc\nZeile 2 (branch1)\n.\nw\nq\n"
        git.add "."
        git.commit "Änderung in branch1"

        git.checkout "master"
        hoppla "a\nAdd line in master.\n.\n2\nc\nZeile 2 (master)\n.\nw\nq\n"
        git.add "."
        git.commit "Änderung in master"

        git.merge "branch1"
        print "Status:"
        print(git.status())
        print "Diff:"
        print(git.diff())
    end
end

local hier=fpp.pwd()
mergedemo(conflict_styles.merge)
fpp.cd(hier)
mergedemo(conflict_styles.diff3)
fpp.cd(hier)
mergedemo(conflict_styles.zdiff3)
