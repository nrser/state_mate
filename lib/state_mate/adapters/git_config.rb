require 'nrser'
require 'nrser/exec'

using NRSER

module StateMate; end
module StateMate::Adapters; end

module StateMate::Adapters::GitConfig
  def self.read key, options = {}
    result = NRSER::Exec.result "git config --global --get %{key}", key: key

    if result.success?
      result.output.chomp
    elsif result.output == ''
      nil
    else
      result.raise_error
    end
  end

  def self.write key, value, options = {}
    action = if read(key, options).nil?
      '--add'
    else
      '--replace'
    end

    result = NRSER::Exec.result(
      "git config --global #{ action } %{key} %{value}",
      key: key,
      value: value
    )
  end
end # GitConfig