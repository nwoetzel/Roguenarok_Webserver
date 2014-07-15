class TiiAnalysis < ActiveRecord::Base
   attr_accessor :jobid

  HUMANIZED_ATTRIBUTES = {
    :jobid => "Job ID"
  }

  def execute(link)
    path                   = File.join(RAILS_ROOT,"public","jobs",self.jobid)
    bootstrap_treeset_file = File.join(path,"bootstrap_treeset_file")
    best_tree_file         = File.join(path,"best_tree")
    excluded_taxa_file     = File.join(path,"excluded_taxa")
    results_path           = File.join(path,"results")
    logs_path              = File.join(path,"logs")
    log_out                = File.join(logs_path,"submit.sh.out")
    log_err                = File.join(logs_path,"submit.sh.err")
    
    current_logfile = File.join(path,"current.log")
    if File.exists?(current_logfile) 
      system "rm #{current_logfile}"
    end
    
    # BOOTSTRAP TREESET, DROPSET, NAME, WORKING DIRECTORY
    opts = {
      "-i" => bootstrap_treeset_file, 
      "-n" => "#{self.jobid}_#{self.id}",
      "-w" => path}
    
    # EXCLUDED TAXA
    if File.exists?(excluded_taxa_file)
      opts["-x"] = excluded_taxa_file
    end
    
    job = Roguenarok.find(:first,:conditions => {:jobid => self.jobid})
    user = User.find(:first, :conditions => {:id => job.user_id})
    email = user.email

    # BUILD SHELL FILE FOR QSUB

    shell_file =File.join(RAILS_ROOT,"public","jobs",self.jobid,"submit.sh")

    command_create_results_folder = "mkdir -p #{results_path}"
    system command_create_results_folder

    command_create_logs_folder = "mkdir -p #{logs_path}"
    system command_create_logs_folder

    command_change_directory = "cd #{path}"

    command_rnr_tii = File.join(RAILS_ROOT,"bioprogs","roguenarok","rnr-lsi")
    opts.each_key {|k| command_rnr_tii  = command_rnr_tii+" "+k+" #{opts[k]} "}
    
    resultfiles = File.join(path,"RnR*")
    command_save_result_files="mv #{resultfiles} #{results_path}"

    command_send_email = "";
    if !(email.nil? || email.empty?)
      command_send_email = File.join(RAILS_ROOT,"bioprogs","ruby","send_email.rb")
      command_send_email = command_send_email + " -e #{email} -l #{link}"
    end
  
    File.open(shell_file,'wb'){|file| 
      file.write(command_change_directory+"\n")
      file.write(command_rnr_tii+"\n")
      file.write(command_save_result_files+"\n")
      file.write(command_send_email+"\n")
      file.write("echo done! > #{current_logfile}\n")
    }

    # submit shellfile into batch system 
    qsub_command = "qsub -o #{log_out} -e #{log_err} #{shell_file}"
    system qsub_command
  end
end
