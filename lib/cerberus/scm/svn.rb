require 'cerberus/utils'

class Cerberus::SCM::SVN
  include Cerberus::Utils

  def initialize(path, config = {})
    raise "Path can't be nil" unless path

    @path, @config = path.strip, config
    @encoded_path = (@path.include?(' ') ? "\"#{@path}\"" : @path)
  end

  def update!
    if test(?d, @path + '/.svn') #check first that it was not locked 
      execute("cleanup") if locked?
      say "Could not unlock svn directory #{@encoded_path}. Please do it manually." if locked? #In case if we could not unlock from command line - ask user to do it
    end

    if test(?d, @path + '/.svn')
      @status = execute("update")
    else
      FileUtils.mkpath(@path) unless test(?d,@path)
      @status = execute("checkout", nil, @config[:scm, :url])
    end
  end

  def has_changes?
    @status =~ /[A-Z]\s+[\w\/]+/
  end

  def current_revision
    info['Revision'].to_i
  end

  def url
    info['URL']
  end

  def last_commit_message
    message = execute("log", "--limit 1 -v")
    #strip first line that contains command line itself (svn log --limit ...)
    if ((idx = message.index('-'*72)) != 0 )
      message[idx..-1]
    else
      message
    end
  end

  def last_author
    info['Last Changed Author']
  end

  private
  def locked?
    execute("st") =~ /^..L/
  end

  def info
    output = execute("info")
    @info ||= YAML.load(output)

    unless @info === Hash or @info['Repository Root'] #.size > 8
      say "Could not parse svn output. Seems source directory #{@encoded_path} is corrupted.\n#{output}"
    end
    @info
  end
    
  def execute(command, parameters = nil, pre_parameters = nil)
    `#{@config[:bin_path]}svn #{command} #{pre_parameters} #{@encoded_path} #{parameters}`
  end
end