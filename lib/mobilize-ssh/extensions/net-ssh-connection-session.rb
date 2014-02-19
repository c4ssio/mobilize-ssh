module Net
  module SSH
    module Connection
      class Session
        #except=true means exception will be raised on exit_code != 0
        def run( _host, _command, _except = true, _streams = [ :stdout, :stderr ], _log = true )

          _ssh, @stdout_data, @stderr_data    = self, "", ""
          @exit_code, @exit_signal, @streams  = nil, nil, _streams

          @host, @command                     = _host, _command

          _ssh.open_channel                 do |_channel|
            _ssh.run_proc _channel, _log
          end
          _ssh.loop

          if                                    _except and @exit_code!=0
            raise                               "#{ @host } stderr: " + @stderr_data
          else
            _result                           = {  'stdout'      => @stdout_data,
                                                   'stderr'      => @stderr_data,
                                                   'exit_code'   => @exit_code,
                                                   'exit_signal' => @exit_signal  }
            _result
          end
        end
        def run_proc( _channel, _log = true )
          _ssh                     = self
          _channel.exec( @command ) do |_ch, _success|
            unless                           _success
              raise                          "FAILED: couldn't execute command (ssh.channel.exec)"
            end
            _channel.on_data                   do |_ch_d, _data|
              @stdout_data                     +=  _data
              _ssh.log_stream(                     :stdout, _data ) if _log
            end

            _channel.on_extended_data          do |_ch_ed, _type, _data|
              @stderr_data                     +=  _data
              _ssh.log_stream(                     :stderr, _data ) if _log
            end

            _channel.on_request("exit-status") do |_ch_exst, _data|
              @exit_code                        = _data.read_long
            end

            _channel.on_request("exit-signal") do |_ch_exsig, _data|
              @exit_signal                      = _data.read_long
            end
          end
        end
        def log_stream( _stream, _data )
          if @streams.include?( _stream )
            puts               "#{ @host } #{ _stream.to_s }: #{ _data }"
          end
        end
      end
    end
  end
end
