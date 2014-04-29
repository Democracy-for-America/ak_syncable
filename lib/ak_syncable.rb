module AkSyncable

  @@actionkit_user_fields = [:address1,:address2,:city,:country,:email,:first_name,:last_name,:middle_name,:name,:phone,:postal,:prefix,:region,:state,:suffix,:zip]

  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def syncs_to(page)
      self.class_variable_set :@@actionkit_page, page
    end
  end

  def sync_to_actionkit(options = {})

    actionkit_attributes = self.class.class_variable_get(:@@synced_attributes)
    actionkit_page = options[:page] || self.class.class_variable_get(:@@actionkit_page)
    
    body = Hash.new

    case actionkit_page
    when String
      body[:page] = actionkit_page
    when Symbol
      body[:page] = self.send(actionkit_page)
    when Proc
      body[:page] = self.instance_exec(&actionkit_page)
    end

    actionkit_attributes.each do |attribute|
      if @@actionkit_user_fields.include? attribute.to_sym
        body[attribute] = self[attribute] || self.send(attribute)
      else
        body['action_' + attribute.to_s] = self[attribute] || self.send(attribute)
      end
    end

    result = HTTParty.post(ENV['ACTIONKIT_PATH'] + 'action/', basic_auth: {username: ENV['ACTIONKIT_USERNAME'], password: ENV['ACTIONKIT_PASSWORD']}, body: body)
    
    # Create the parent page if it does not exist.
    if result.response.class == Net::HTTPBadRequest
      HTTParty.post(ENV['ACTIONKIT_PATH'] + 'petitionpage/', basic_auth: {username: ENV['ACTIONKIT_USERNAME'], password: ENV['ACTIONKIT_PASSWORD']}, body: {name: body[:page], title: body[:page]})
      second_attempt = HTTParty.post(ENV['ACTIONKIT_PATH'] + 'action/', basic_auth: {username: ENV['ACTIONKIT_USERNAME'], password: ENV['ACTIONKIT_PASSWORD']}, body: body)
      raise 'Failed to sync with ActionKit' if JSON.parse(second_attempt.body)['id'].nil?
    else
      raise 'Failed to sync with ActionKit' if JSON.parse(result.body)['id'].nil?
    end

    actionkit_id = JSON.parse(result.body)['id'] || JSON.parse(second_attempt.body)['id']

    if self.has_attribute? :actionkit_id
      self.update_column :actionkit_id, actionkit_id
    end

    return actionkit_id

  end

end
