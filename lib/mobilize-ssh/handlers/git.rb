module Mobilize
  module Git
    def Git.config
      Base.config('git')
    end

    def Git.host(domain)
      Git.config['domains'][domain]['host']
    end

    def Git.domains
      Git.config['domains'].keys
    end

    def Git.default_domain
      Git.domains.first
    end

    def Git.repo_key(domain,repo)
      begin
        Git.config['domains'][domain]['repo_keys'][repo]
      rescue
        nil #no key for public repos
      end
    end

    # converts a source path or target path to a dst in the context of handler and stage
    def Git.path_to_dst(path,stage_path,gdrive_slot)
      red_path = path.split("://").last
      git_url = Git.url_by_path(red_path)
      return Dataset.find_or_create_by_url(git_url)
    end

    def Git.url_by_path(path)
      path_nodes = path.split("/")
      domain = path_nodes.first.to_s
      revision = "HEAD"
      if Git.domains.include?(domain)
        repo = path_nodes[1..2].join("/")
        file_path = path_nodes[3..-1].join("/")
      else
        domain = Git.default_domain
        repo = path_nodes[0..1].join("/")
        file_path = path_nodes[2..-1].join("/")
      end
      url = "git://#{domain}/#{repo}/#{revision}/#{file_path}"
      return url
    end

    #return path to tar.gz of git repo
    def Git.pack(domain,repo,revision="HEAD")
      repo_dir = Git.pull(domain,repo,revision)
      repo_name = repo.split("/").last
      tar_gz_path = "#{repo_dir}/../#{repo_name}.tar.gz"
      pack_cmd = "cd #{repo_dir} && git archive #{revision} --format=tar.gz > #{tar_gz_path}"
      pack_cmd.bash(true)
      FileUtils.rm_r(repo_dir,:force=>true)
      return tar_gz_path
    end

    #confirm that git file exists
    def Git.exists?(url)
      domain,repo,revision,file_path=[]
      url.split("/").ie do |url_nodes|
        domain    = url_nodes[2]
        repo      = url_nodes[3..4].join("/")
        revision  = url_nodes[5]
        file_path = url_nodes[6..-1].join("/")
      end
      repo_dir = Git.pull(domain,repo,revision)
      full_path = "#{repo_dir}/#{file_path}"
      exists = File.exists?(full_path)
      if exists
        FileUtils.rm_r(repo_dir,:force=>true)
        return exists
      else
        raise "Unable to find #{full_path}"
      end
    end

    #pulls a git repo and sets it to the specified revision in the
    #specified folder
    def Git.pull(domain,repo,revision,run_dir=Dir.mktmpdir)
      domain_properties = Git.config['domains'][domain]
      user,host= ['user','host'].map{|k| domain_properties[k]}
      key = Git.repo_key(domain,repo)
      #create folder for repo and command
      run_file_path = run_dir + "/cmd.sh"
      #put together command
      git_prefix = key ? "ssh-add #{Base.root}/#{key};" : ""
      git_suffix = (revision=="HEAD" ? " --depth=1" : "; git checkout -q #{revision}")
      #add keys, clone repo, go to specific revision, execute command
      full_cmd = "cd #{run_dir};#{git_prefix}git clone -q #{user}@#{host}:#{repo}.git#{git_suffix}"
      #put command in file, run ssh-agent bash on it
      File.open(run_file_path,"w") {|f| f.print(full_cmd)}
      run_cmd = "ssh-agent bash #{run_file_path}"
      #run the command, it will return an exception if there are issues
      run_cmd.bash(true)
      repo_name = repo.split("/").last
      repo_dir = "#{run_dir}/#{repo_name}"
      return repo_dir
    end

    def Git.read_by_dataset_path( _dst_path, _user_name, *_args)
      _domain,   _repo,
      _revision, _file_path     = []
      _dst_path.split("/").ie do |_path_nodes|
        _domain                 = _path_nodes[0]
        _repo                   = _path_nodes[1..2].join "/"
        _revision               = _path_nodes[3]
        _file_path              = _path_nodes[4..-1].join "/"
      end
      #slash in front of path
      _repo_dir                 = Git.pull  _domain, _repo, _revision
      if _file_path.strip.length > 0
        _full_path              = "#{ _repo_dir }/#{ _file_path }"
        _result                 = "cat #{ _full_path}".bash true
        FileUtils.rm_r            _repo_dir, force: true
      else
        _base_name, _dir_name   = _repo_dir.ie{ |_dir| [ File.basename( _dir), File.dirname( _dir ) ] }
        _pack_cmd               = "cd #{ _dir_name } && tar zcvf #{ _base_name }.tar.gz #{ _base_name }"
        _pack_cmd.bash(true)
        _result                 = "cat #{ _repo_dir }.tar.gz".bash( true )
        FileUtils.rm_r            _repo_dir, force: true
        FileUtils.rm_r            "#{ _repo_dir }.tar.gz", force: true
      end
      return _result
    end
  end
end
