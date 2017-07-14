import net
import json
import strutils
import os

var s = newSocket()

s.connect("localhost", Port(4242))

proc readUntil(s: Socket; endChar: char): string =
  var data: string = ""
  var tmp: char
  while true:
    if 0 == s.recv(addr(tmp), 1):
      raise newException(IOError, "EOF") # TODO EOFException
    if tmp == endChar:
      break
    data &= tmp
  return data

proc readLine(s: Socket): string =
  readUntil(s, '\l')

proc printWatch(c1, c2, c3, c4: string) =
  proc format(str: string): string =
    case str
    of "empty": "     "
    of "energy": "  +  "
    of "wall", "": "====="
    else: str
  echo "      _______"
  echo "      |" & format(c1) & "|"
  echo "______|-----|______"
  echo "|" & format(c2) & "|" & format(c3) & "|" & format(c4) & "|"
  echo "¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯"

type
  Goal = tuple[dir: string, num: int]

template checkWin(str: string): untyped =
  echo "STR[" & str & "]"
  if str == "win":
    echo "YOU WIN!"
    quit(0)
  elif str == "die":
    echo "You lose! :("
    quit(0)

try:
  var position = parseJson(readLine(s))
  var goal: Goal = ("", -1)
  var (x, y, dir) = (position[0].getNum, position[1].getNum, position[2].getNum)

  while true:
    # turn start. Always "watch".
    var data = ""
    while true:
      s.send("watch\n")
      data = s.readLine
      checkWin(data)
      if data != "wait for next turn":
        sleep(100)
        break
    var seen = parseJson(data)
    var (c1, c2, c3, c4) = (seen[0].getStr, seen[1].getStr, seen[2].getStr, seen[3].getStr)
    printWatch(c1, c2, c3, c4)
    # most important case: WE'RE RUNNING INTO A WALL! AAAAAH.
    if c1 == "":
      s.send("leftfwd\n")
      goal = (dir: "", num: -1)
    # almost there, just need to shift direction. next step will be gather.
    elif goal.num == 0 and goal.dir != "":
      s.send(goal.dir & "fwd\n")
      goal.dir = ""
    # we still have some work to do before attaining our goal.
    elif goal.num > 0:
      s.send("forward\n")
      goal.num -= 1
    # we did iiiit! just need to gather now, we're sitting on the cell.
    elif goal.num == 0 and goal.dir == "":
      s.send("gather\n")
      goal.num = -1
    # num == -1, rebuild goal.
    else:
      if c1 == "energy": # next cell
        goal = (dir: "", num: 0)
        s.send("forward\n")
      elif c3 == "energy": # 2 cells ahead
        goal = (dir: "", num: 1)
        s.send("forward\n")
      elif c2 == "energy":
        goal = (dir: "left", num: 1)
        s.send("forward\n")
      elif c4 == "energy":
        goal = (dir: "right", num: 1)
        s.send("forward\n")
      elif c1.startsWith("#0x"): # dodge other players. We don't know how much energy we have...
        s.send("leftfwd")
      else:
        s.send("forward")
    data = s.readLine # read the "ok" (... or "wait for next turn")
    checkWin(data)

    sleep(700)
except IOError:
  discard # TODO EOFException
