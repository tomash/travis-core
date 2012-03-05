require 'spec_helper'

class RequestMock
  include Module.new {
    def update_attributes!(*); end
    def create_build!; stub('build', :matrix => [stub('job:test', :state => :created, :state= => nil)]) end
  }
  include Request::States

  attr_accessor :state
  def save!; end
  def commit; @commit ||= stub('commit', :branch => 'master') end
  def repository; @repository||= stub(:slug => 'foo/bar') end
  def attribute_names; %w(id repository_id state source payload) end
end

describe Request::States do
  let(:payload) { GITHUB_PAYLOADS['gem-release'] }
  let(:request) { RequestMock.new }

  describe :create_build! do
    xit 'notifies about a created event for each test job in the build matrix' do
      Travis::Notifications.expects(:dispatch).with('job:test:created', anything).once
      request.create_build!
    end
  end

  describe 'events' do
    it 'has the state :created when just created' do
      request.state.should == :created
    end

    describe 'start!' do
      it 'changes the state to :started' do
        request.start!
        request.state.should == :started
      end

      it 'saves the request' do
        request.expects(:save!).times(2) # TODO why exactly do we save the record twice?
        request.start!
      end
    end

    describe 'configure!' do
      let(:data) { { :rvm => 'rbx' } }

      before(:each) do
        request.stubs(:create_build!)
      end

      describe 'with an approved request' do
        before :each do
          request.stubs(:approved?).returns(true)
        end

        it 'changes the state to :finished (because it also finishes the request)' do
          request.configure!(data)
          request.state.should == :finished
        end

        it 'saves the request' do
          request.expects(:save!).times(2)
          request.configure!(data)
        end

        it 'creates the build' do
          request.expects(:create_build!)
          request.configure!(data)
        end
      end

      describe 'with an unapproved request' do
        before :each do
          request.stubs(:approved?).returns(false)
        end

        it 'changes the state to :finished (because it also finishes the request)' do
          request.configure!(data)
          request.state.should == :finished
        end

        it 'saves the request' do
          request.expects(:save!).times(2)
          request.configure!(data)
        end

        it 'does not create a build' do
          request.expects(:create_build).never
          request.configure!(data)
        end
      end
    end

    describe 'finish!' do
      it 'changes the state to :finish' do
        request.finish!
        request.state.should == :finished
      end

      it 'saves the request' do
        request.expects(:save!).times(2)
        request.finish!
      end
    end
  end

  describe :approved? do
    describe 'returns true' do
      it 'if there is no branches option' do
        request.stubs(:config).returns({})
        request.should be_approved
      end

      it 'if the branch is included the branches option given as a string' do
        request.stubs(:config).returns(:branches => 'master, develop')
        request.should be_approved
      end

      it 'if the branch is included in the branches option given as an array' do
        request.stubs(:config).returns(:branches => ['master', 'develop'])
        request.should be_approved
      end

      it 'if the branch is included in the branches :only option given as a string' do
        request.stubs(:config).returns(:branches => { :only => 'master, develop' })
        request.should be_approved
      end

      it 'if the branch is included in the branches :only option given as an array' do
        request.stubs(:config).returns(:branches => { :only => ['master', 'develop'] })
        request.should be_approved
      end

      it 'if the branch is not included in the branches :except option given as a string' do
        request.stubs(:config).returns(:branches => { :except => 'github-pages, feature-*' })
        request.should be_approved
      end

      it 'if the branch is not included in the branches :except option given as an array' do
        request.stubs(:config).returns(:branches => { :except => ['github-pages', 'feature-*'] })
        request.should be_approved
      end
    end

    describe 'returns false' do
      before(:each) { request.commit.stubs(:branch).returns('staging') }

      it 'if the branch is not included the branches option given as a string' do
        request.stubs(:config).returns(:branches => 'master, develop')
        request.should_not be_approved
      end

      it 'if the branch is not included in the branches option given as an array' do
        request.stubs(:config).returns(:branches => ['master', 'develop'])
        request.should_not be_approved
      end

      it 'if the branch is not included in the branches :only option given as a string' do
        request.stubs(:config).returns(:branches => { :only => 'master, develop' })
        request.should_not be_approved
      end

      it 'if the branch is not included in the branches :only option given as an array' do
        request.stubs(:config).returns(:branches => { :only => ['master', 'develop'] })
        request.should_not be_approved
      end

      it 'if the branch is included in the branches :except option given as a string' do
        request.stubs(:config).returns(:branches => { :except => 'staging, feature-*' })
        request.should_not be_approved
      end

      it 'if the branch is included in the branches :except option given as an array' do
        request.stubs(:config).returns(:branches => { :except => ['staging', 'feature-*'] })
        request.should_not be_approved
      end

      it 'if the repository is blacklisted (e.g. a rails fork)' do
        request.stubs(:config).returns({})
        request.stubs(:blacklisted?).returns(true)
        request.should_not be_approved
      end
    end
  end

  describe 'extract_attributes' do
    it 'discards values from the given hash that are not attributes' do
      result = request.send(:extract_attributes, { :state => :finished, :status => 1, 'source' => 'github' })
      result.should == { :state => :finished, :source => 'github' }
    end
  end

  describe 'is_blacklisted?' do
    def with_slug(slug)
      request.stubs(:repository).returns(stub(:slug => slug))
      # these stubs were commented out to ensure proper
      # format of regexps in default provided whiteblacklist.yml
      #request.class.stubs(:blacklist_rules).returns([/\/rails$/])
      #request.class.stubs(:whitelist_rules).returns([/^rails\/rails/])
    end

    it 'returns false for a repository slug travis-ci/travis-ci' do
      with_slug 'travis-ci/travis-ci'
      request.send(:blacklisted?).should be_false
    end

    it 'returns false for a repository slug rails/rails' do
      with_slug 'rails/rails'
      request.send(:blacklisted?).should be_false
    end

    it 'returns true for a repository slug travis-ci/rails' do
      with_slug 'travis-ci/rails'
      request.send(:blacklisted?).should be_true
    end
  end
end
