// Stolen (with permission) from the gracious vbatts
//    https://github.com/vbatts/flaming-happiness
package main

import (
	"encoding/json"
	"flag"
	"github.com/kr/beanstalk"
	"github.com/vbatts/flaming-happiness/common"
	"log"
	"time"
)

func main() {
	flag.Parse()

	if len(ignoreChannels) > 0 {
		common.SetIgnores(ignoreChannels)
	}

	var (
		bs *beanstalk.Conn
		err error
	)

	if len(flag.Args()) >= 1 {
		bs, err = beanstalk.Dial("tcp", flag.Args()[0])

		if err != nil {
			log.Fatal(err)
		}

		if !quiet {
			log.Printf("Connected to [%s]", flag.Args()[0])
		}

		if len(flag.Args()) >= 2 {
			bs.Tube.Name = flag.Args()[1]
		}
	} else {
		log.Fatalf("provide the beanstalk publisher! like example.com:11300")
	}

	//Clear out the old messages before we start back up
	for {
		id, msg, err := bs.Reserve(5 * time.Second)

		if !quiet {
			noti_msg := common.IrcNotify{}
			json.Unmarshal(msg, &noti_msg)

			log.Printf("removing old message [%s]", noti_msg.Message)
		}

		if err != nil {
			break
		}

		err = bs.Delete(id)

		if err != nil {
			log.Fatal(err)
		}
	}

	for {
		id, msg, err := bs.Reserve(5 * time.Second)

		if err == nil {
			noti_msg := common.IrcNotify{}
			json.Unmarshal(msg, &noti_msg)

			go common.Display(noti_msg, linger, quiet)

			err = bs.Delete(id)

			if err != nil {
				log.Fatal(err)
			}
		}

		time.Sleep(500 * time.Millisecond)
	}
}

var (
	linger         int64 = 5
	quiet          bool  = true
	ignoreChannels string
)

func init() {
	flag.Int64Var(&linger, "linger",
		linger, "time to let the notification linger")
	flag.BoolVar(&quiet, "quiet",
		false, "less output")
	flag.StringVar(&ignoreChannels, "ignore",
		"", "comma seperated list of pattern of channels to ignore")
}