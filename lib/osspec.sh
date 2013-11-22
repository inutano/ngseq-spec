#$ -o /home/inutano/project/opensequencespec/log -S /home/inutano/local/bin/zsh -j y -l mem_req=16G,s_vmem=16G -pe def_slot 16

export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init - zsh)"
cd /home/inutano/project/opensequencespec/lib
/home/inutano/.rbenv/shims/ruby /home/inutano/project/opensequencespec/lib/sequencespec.rb
