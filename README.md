# AUTOPROXIES

Emulates a terminal with each command a different proxychains. The code is written in Bash and calls [TheSpeedX](https://github.com/TheSpeedX/) programs. Its repo [PROXY-List](https://github.com/TheSpeedX/PROXY-List) and [socker](https://github.com/TheSpeedX/socker) which tests if the proxies work.

## HOW To RUN

allow program execution

``` chmod +x autoproxies.sh```

run the program

``` ./autoproxies.sh ```

All the parameters are optional.

### Requirements

 - Proxychains
 - socker.py program from [socker](https://github.com/TheSpeedX/socker) by TheSpeedX

If you want to use tor you need to have it installed.

 - tor

### Help

```
$ ./autoproxies.sh -h
Saved timestamp: 1730366002
Usage: ./autoproxies.sh [options...]
  -h, --help              display this help message
  -t, --tor               add Tor sockets to proxy list (need root privileges)
  -k, --keep              keep the older proxy files
  -f, --force             force download of new proxies
  -m, --mode <value>      choose mode of filtering proxies
             1 = Only really fast proxies but limited number
             2 = (Default) Between 1 and 3. Good balance between speed and randomness
             3 = More proxies (and increase randomness) but maybe slower```
