module Mobilize
  module Ssh
    def Ssh.config
      Base.config('ssh')[Base.env]
    end

    def Ssh.tmp_file_dir
      dir = "#{Base.root}/tmp/ssh/"
      "mkdir -p #{dir}".bash
      return dir
    end

    def Ssh.host(node)
      Ssh.config['nodes'][node]['host']
    end

    def Ssh.gateway(node)
      Ssh.config['nodes'][node]['gateway']
    end

    #determine if current machine is on host domain, needs gateway if one is provided and it is not
    def Ssh.needs_gateway?(node)
      host_domain_name = Ssh.host(node)['name'].split(".")[-2..-1].join(".")
      return true if Ssh.gateway(node) and Socket.domain_name == host_domain_name
    end

    def Ssh.pop_comm_dir(comm_dir,file_hash)
      "rm -rf #{comm_dir}".bash
      file_hash.each do |fname,fdata|
        fpath = "#{comm_dir}/#{fname}"
        #for now, only gz is binary
        binary = fname.ends_with?(".gz") ? true : false
        #read data from cache, put it in a tmp_file
        Ssh.tmp_file(fdata,binary,fpath)
      end
      return true if file_hash.keys.length>0
    end

    def Ssh.scp(node,from_path,to_path)
      name,key,port,user = Ssh.host(node).ie{|h| ['name','key','port','user'].map{|k| h[k]}}
      key_path = "#{Base.root}/config/#{key}"
      opts = {:port=>(port || 22),:keys=>key_path}
      if Ssh.needs_gateway?(node)
        gname,gkey,gport,guser = Ssh.gateway(node).ie{|h| ['name','key','port','user'].map{|k| h[k]}}
        gkey_path = "#{Base.root}/config/#{gkey}"
        gopts = {:port=>(gport || 22),:keys=>gkey_path}
        return Net::SSH::Gateway.sync(gname,guser,name,user,from_path,to_path,gopts,opts)
      else
        Net::SCP.start(name,user,opts) do |scp|
          scp.upload!(from_path,to_path,:recursive=>true)
        end
      end
      return true
    end

    def Ssh.run(node,command,file_hash=nil,except=true,su_user=nil,err_file=nil)
      name,key,port,user,dir = Ssh.host(node).ie{|h| ['name','key','port','user','dir'].map{|k| h[k]}}
      key_path = "#{Base.root}/config/#{key}"
      opts = {:port=>(port || 22),:keys=>key_path}
      su_user ||= user
      file_hash ||= {}
      #make sure the dir for this command is clear
      comm_md5 = [su_user,node,command,file_hash.keys.to_s].join.to_md5
      comm_dir = "#{Ssh.tmp_file_dir}#{comm_md5}"
      #populate comm dir with any files
      Ssh.pop_comm_dir(comm_dir,file_hash)
      #move any files up to the node
      rem_dir = nil
      if File.exists?(comm_dir)
        #make sure user starts in rem_dir
        rem_dir = "#{dir}#{comm_md5}/"
        command = ["cd #{rem_dir}",command].join(";") if dir
        Ssh.scp(node,comm_dir,rem_dir)
        "rm -rf #{comm_dir}".bash
        if su_user
          chown_command = "sudo chown -R #{su_user} #{rem_dir}"
          Ssh.run(node,chown_command)
        end
      else
        #cd to dir if provided
        command = ["cd #{dir}",command].join(";") if dir
      end
      if su_user != user
        #wrap the command in sudo su -c
        command = %{sudo su #{su_user} -c "#{command}"}
      end
      result = nil
      #one with gateway, one without
      if Ssh.needs_gateway?(node)
         gname,gkey,gport,guser = Ssh.gateway(node).ie{|h| ['name','key','port','user'].map{|k| h[k]}}
         gkey_path = "#{Base.root}/config/#{gkey}"
         gopts = {:port=>(gport || 22),:keys=>gkey_path}
         result = Net::SSH::Gateway.run(gname,guser,name,user,command,gopts,opts,except,err_file)
      else
         Net::SSH.start(name,user,opts) do |ssh|
           result = ssh.run(command,except,err_file)
         end
      end
      #delete remote dir if necessary
      if rem_dir
        del_cmd = "rm -rf #{rem_dir}"
        if su_user
          del_cmd = %{sudo su #{su_user} -c "#{del_cmd}"}
        end
        Ssh.run(node,del_cmd)
      end
      result
    end

    def Ssh.read(node,path)
      Ssh.run(node,"cat #{path}")
    end

    def Ssh.write(node,fdata,to_path,binary=false)
      from_path = Ssh.tmp_file(fdata,binary)
      Ssh.scp(node,from_path,to_path)
      "rm #{from_path}".bash
      return true
    end

    def Ssh.tmp_file(fdata,binary=false,fpath=nil)
      #creates a file under tmp/files with an md5 from the data
      tmp_file_path = fpath || "#{Ssh.tmp_file_dir}#{(fdata + Time.now.utc.to_f.to_s).to_md5}"
      write_mode = binary ? "wb" : "w"
      #make sure folder is created
      "mkdir -p #{tmp_file_path.split("/")[0..-2].join("/")}".bash
      #write data to path
      File.open(tmp_file_path,write_mode) {|f| f.print(fdata)}
      return tmp_file_path
    end

    def Ssh.run_by_job_id(job_id)
      j = Job.find(job_id)
      param_hash = JSON.parse(j.params)
      command = param_hash['ssh_command']
      node = param_hash['node']
      su_user = param_hash['su_user']
      file_hash = {}
      j.dataset_array.each do |dst|
        file_hash[dst.name.split('/').last]=dst.read
      end
      Ssh.run(node,command,file_hash,su_user)
    end
  end
end