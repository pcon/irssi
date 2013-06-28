# Setup
- Install `beanstalkd` on a system that both your irssi client _(producer)_ and the system you want notifications on _(consumer)_

## Producer
- Install the `JSON` perl module as well as the `Queue::Beanstalk` module
- Download the `beanstalkNotify.pl` file into your _~/.irssi/scripts/_ directory

## Consumer
- Install `pyyaml` and `beanstalkc`.  These can be installed via python-pip.
- Download the `beanstalk-notify.py` file onto your consumer system

# Configuration
## Producer
- Install the script by running `/script load beanstalkNotify`
- Set your server: `/set beanstalk_server beanstalk.example.com`
- Set your port: `/set beanstalk_port 12345`

## Consumer
- Modify the `beanstalk-notify.py` file to point to your beanstalkd server
- Run the consumer script `python beanstalk-notify.py&`