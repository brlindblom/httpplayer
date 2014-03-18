# httpplayer

A tool for cli-ifying the tedious task of interacting with crusty, old cgi applications (with REST support coming soon!)

## Why?

Because old, multi-part form-driven cgi applications suck in a huge way because there _is_ no means for automation, especially when your developers didn't have the foggiest sense of providing an API when
they wrote it, and I was, unfortunately, forced to use such an app for an employer... and was feeling
lazy.

## Example?

The 90's called... they want their disgusting, error-prone, web app from the bowels of hell back!  But
thankfully, we can work with it like so:

```
$ ls
scenarios   httpplayer   httpplayer.rb

$ cat scenario/adduser.rb
# We will group our input parameters by our URI paths
HttpplayerScenario.scenario = {
  :url => "https://crustyoldapp.com",
  :paths => {
    "/cgi-bin/adduser.cgi" => {
      :method => :post,
      :validation => /^.*$/,
      :bad_out => /<p class=['"]red['"]>(.+?)<\/p>/,
      :parse_and_forward_inputs => true,
      :params => {
        :username => { 
          :format => /^[a-zA-Z][a-zA-Z0-9\-]+$/,
          :id => "user_name",
          :label => "short hostname",
          :mandatory => true,
          :flags => ["-u", "--username [USERNAME]"]
        },
        :email => {
          :format => /^.+@(\+\.?)+$/,
          :label => "E-Mail Address",
          :mandatory => true,
          :clone => [ :email_confirm ],
          :flags => ["-e", "--email [EMAIL]"]
        },
        :password => {
          :label => "password",
          :clone => [ :password_confirm ],
          :mandatory => true,
          :flags => ["-p", "--password [PASSWORD]"]
        }
      }
    },
    "/cgi-bin/confirm_adduser.cgi" => {
      :method => :post,
      :validation => /^.*$/,
      :bad_out => /<p class=['"]red['"]>(.+?)<\/p>/,
      :depends => "/cgi-bin/adduser.cgi",
      :params => {
        :confirmation => { :mandatory => true, :default => "YES" }
      }
    }
  }
}

# Yeah, for some reason, this stupid application breaks if the email is not
# upper-case
def HttpplayerScenario.email_transform(scenario, email)
  { :email => email.upcase }
end
```

Let's play this scenario!

```
$ httpplayer.rb adduser -h
Usage: httpplayer.rb [options] adduser [options]
    -u, --username [USERNAME]        short hostname
    -p, --password [PASSWORD]        password
    -e, --email [EMAIL]              E-Mail Address
    -h, --help                       Display this help
exit

Sweet!  Automagical command help!

$ httpplayer.rb adduser -u joeuser -e joeuser@example.com -p SecretPassword
User added!
```

All params for all paths are parsed for command arguments.  Arguments are validated against any format
specifiers included.  :clone can make a parameter appear as another parameter with a different name.  
This is useful for crappy cgis that duplicate data all over the place (yes, it happens).

Dependencies between different path end-points are handled with :depends statements.  Its handled as an acyclic graph and sorted with a topsort.

Tranform methods can be defined to massage data for some expected format.  They can be defined for any param and can even be used to take in a single param and provide multiple subsequent parameters.

Todo:

Cookie handling
RESTful support
