class UsersController < ApplicationController
  before_action :authenticate_account!

  def index
    @q = current_account.users.includes(:user_attributes, :campaigns, :campaign_users, :tags)
                        .ransack(params[:q])
    @q.build_grouping unless @q.groupings.any?
    @q.sorts = 'created_at DESC' if @q.sorts.empty?

    @users = if params[:limit_count].present?
               @q.result(distinct: true).limit(params[:limit_count])
             else
               @q.result(distinct: true).page(params[:page])
             end
    @associations = [:campaigns, :tags, :campaign_users, :user_attributes]
    @total_user_count = params[:limit_count].present? ? @users.count : @q.result(distinct: true).count
  end

  def new; end

  def create
    if params[:file].present? && params[:tags].present?

      name = "#{(0...50).map { ('a'..'z').to_a[rand(26)] }.join}-#{params[:file].original_filename}"
      directory = 'public/upload'
      path = File.join(directory, name)
      File.open(path, 'wb') { |f| f.write(params[:file].read) }

      ImportUsersJob.perform_later(current_account.id, name, params[:tags])

      @result = 'Your user list importing in background. It will take awhile.'
    else
      @result = { imported_users: 0, import_errors: 'Tags and Csv file required.' }
    end
    redirect_to new_user_path, notice: @result
  end

  def destroy
    @user = current_account.users.find params[:id]
    @user.user_attributes.destroy_all
    @user.destroy
    respond_to do |format|
      format.html { redirect_to users_url, notice: 'User was successfully destroyed.' }
      format.json { head :no_content }
    end
  end
end