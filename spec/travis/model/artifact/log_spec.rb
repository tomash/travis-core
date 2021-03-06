require 'spec_helper'
require 'support/active_record'

describe Artifact::Log do
  include Support::ActiveRecord

  describe ".append" do
    let(:job) { Factory.create(:test, :log => Factory.create(:log, :content => '')) }

    it "appends streamed build log chunks" do
      lines = [
        "$ git clone --depth=1000 --quiet git://github.com/intridea/omniauth.git ~/builds/intridea/omniauth\n",
        "$ git checkout -qf 662af2708525b776aac580b10cc903ba66050e06\n",
        "$ bundle install --pa"
      ]
      0.upto(2) do |ix|
        Artifact::Log.append(job.id, lines[ix])
        lines[0, ix + 1].join.should eql(job.reload.log.content)
      end
    end
  end
end

