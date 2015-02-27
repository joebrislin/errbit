require 'spec_helper'

describe "apps/problems/show.html.haml", :type => :view do
  let(:problem) { Fabricate(:problem) }
  let(:comment) { Fabricate(:comment) }

  before do
    allow(view).to receive(:resource_app).and_return(problem.app)
    assign :problem, problem
    assign :comment, comment
    assign :notices, problem.notices.page(1).per(1)
    assign :notice, problem.notices.first

    allow(controller).to receive(:current_user) { Fabricate(:user) }
  end

  def with_issue_tracker(tracker, problem)
    # problem with has_one and sti, cause reverse creating
    tracker.create :api_token => "token token token", :project_id => "1234", :app => problem.app
    assign :problem, problem
    allow(view).to receive(:resource_app).and_return(problem.app)
  end

  describe "content_for :action_bar" do
    def action_bar
      view.content_for(:action_bar)
    end

    it "should confirm the 'resolve' link by default" do
      render
      expect(action_bar).to have_selector('a.resolve[data-confirm="%s"]' % I18n.t('problems.confirm.resolve_one'))
    end

    it "should confirm the 'resolve' link if configuration is unset" do
      allow(Errbit::Config).to receive(:confirm_err_actions).and_return(nil)
      render
      expect(action_bar).to have_selector('a.resolve[data-confirm="%s"]' % I18n.t('problems.confirm.resolve_one'))
    end

    it "should not confirm the 'resolve' link if configured not to" do
      allow(Errbit::Config).to receive(:confirm_err_actions).and_return(false)
      render
      expect(action_bar).to have_selector('a.resolve[data-confirm="null"]')
    end

    it "should link 'up' to HTTP_REFERER if is set" do
      url = 'http://localhost:3000/problems'
      controller.request.env['HTTP_REFERER'] = url
      render
      expect(action_bar).to have_selector("span a.up[href='#{url}']", :text => 'up')
    end

    it "should link 'up' to app_problems_path if HTTP_REFERER isn't set'" do
      controller.request.env['HTTP_REFERER'] = nil
      problem = Fabricate(:problem_with_comments)
      allow(view).to receive(:problem).and_return(problem)
      allow(view).to receive(:resource_app).and_return(problem.app)
      render

      expect(action_bar).to have_selector("span a.up[href='#{app_path(problem.app)}']", :text => 'up')
    end

    context 'create issue links' do
      it 'should allow creating issue for github if current user has linked their github account' do
        user = Fabricate(:user, :github_login => 'test_user', :github_oauth_token => 'abcdef')
        allow(controller).to receive(:current_user) { user }

        problem = Fabricate(:problem_with_comments, :app => Fabricate(:app, :repo_url => "https://github.com/test_user/test_repo"))
        assign :problem, problem
        allow(view).to receive(:resource_app).and_return(problem.app)
        render

        expect(action_bar).to have_selector("span a.github_create.create-issue", :text => 'create issue')
      end

      it 'should allow creating issue for github if application has a github tracker' do
        problem = Fabricate(:problem_with_comments, :app => Fabricate(:app, :repo_url => "https://github.com/test_user/test_repo"))
        with_issue_tracker(GithubIssuesTracker, problem)
        assign :problem, problem
        allow(view).to receive(:resource_app).and_return(problem.app)
        render

        expect(action_bar).to have_selector("span a.github_create.create-issue", :text => 'create issue')
      end

      context "without issue tracker associate on app" do
        let(:problem) { Fabricate :problem, :app => app }
        let(:app) { Fabricate :app }

        it 'not see link to create issue' do
          assign :problem, problem
          allow(view).to receive(:resource_app).and_return(problem.app)
          render
          expect(view.content_for(:action_bar)).to_not match(/create issue/)
        end

      end

      context "with lighthouse tracker on app" do
        let(:app) { Fabricate :app, :issue_tracker => tracker }
        let(:tracker) { Fabricate :lighthouse_tracker }
        context "with problem without issue link" do
          let(:problem) { Fabricate :problem, :app => app }
          it 'not see link if no issue tracker' do
            assign :problem, problem
            allow(view).to receive(:resource_app).and_return(problem.app)
            render
            expect(view.content_for(:action_bar)).to match(/create issue/)
          end

        end

        context "with problem with issue link" do
          let(:problem) { Fabricate :problem, :app => app, :issue_link => 'http://foo' }

          it 'not see link if no issue tracker' do
            assign :problem, problem
            allow(view).to receive(:resource_app).and_return(problem.app)
            render
            expect(view.content_for(:action_bar)).to_not match(/create issue/)
          end
        end

      end
    end
  end

  describe "content_for :comments with comments disabled for configured issue tracker" do
    before do
      allow(Errbit::Config).to receive(:allow_comments_with_issue_tracker).and_return(false)
      allow(Errbit::Config).to receive(:use_gravatar).and_return(true)
    end

    it 'should display comments and new comment form when no issue tracker' do
      problem = Fabricate(:problem_with_comments)
      assign :problem, problem
      allow(view).to receive(:resource_app).and_return(problem.app)
      render

      expect(view.content_for(:comments)).to include('Test comment')
      expect(view.content_for(:comments)).to have_selector('img[src^="http://www.gravatar.com/avatar"]')
      expect(view.content_for(:comments)).to include('Add a comment')
    end

    context "with issue tracker" do
      it 'should not display the comments section' do
        problem = Fabricate(:problem)
        with_issue_tracker(PivotalLabsTracker, problem)
        render
        expect(view.view_flow.get(:comments)).to be_blank
      end

      it 'should display existing comments' do
        problem = Fabricate(:problem_with_comments)
        problem.reload
        with_issue_tracker(PivotalLabsTracker, problem)
        render

        expect(view.content_for(:comments)).to include('Test comment')
        expect(view.content_for(:comments)).to have_selector('img[src^="http://www.gravatar.com/avatar"]')
        expect(view.content_for(:comments)).to_not include('Add a comment')
      end
    end
  end
end
