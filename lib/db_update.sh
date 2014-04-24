#$ -S /home/inutano/local/bin/zsh -j y -l mem_req=2G,s_vmem=2G -pe def_slot 16

# manual="--manual"
manual=""
export PATH="/home/inutano/.rbenv/bin:$PATH"
eval "$(rbenv init - zsh)"
(/home/inutano/.rbenv/shims/ruby /home/inutano/project/sra_qualitycheck_v2/lib/db_update.rb --update ${manual} 2>&1) >> /home/inutano/project/sra_qualitycheck_v2/log/db.log
