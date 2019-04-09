globals [counterSpawn playersFighted playerSpawns goldGiven goldFromFees counterTrades finishedGame]
breed [weapons weapon]
breed [players player]
weapons-own [
  item-level ;;
  crit ;;
  strength ;;
  speed ;;
  maxPrice ;;
  minPrice ;;
  startPrice ;;
  basePrice ;;

  originYcor ;;
  ownerMaxPrice ;;
  ownerMinPrice ;;
  ownerStartPrice ;;
]
players-own [
  current-messages ;; Lista de mensajes actuales
  next-messages    ;; Lista de mensajes para la siguiente iteración
  resting ;;boolean mode
  item-level ;;
  strength ;;
  crit ;;
  speed ;;
  energy ;;
  gold ;;
  loot ;;
  winner ;;
  weapon-power ;;
  offeredMax ;;
  alreadyOffered ;;
  lootCounter ;;
]

to setup
  clear-all
  reset-ticks
  set playersFighted []
  set playerSpawns []
  set goldGiven 0
  set finishedGame false
  set goldFromFees 0
  ask patches [set pcolor 32 ]
  setup-throne
  setup-market
  setup-battleground
  setup-persons


end




to go
  if finishedGame[stop]
  swap-messages            ;; Activamos los mensajes mandados en la iteración anterior
  ;; move? do something?   ;; Actuamos
  generate-items
  run-players
  process-messages         ;; Procesamos los mensajes
  tick
end

to generate-items
  foreach playersFighted [[i] -> set playersFighted remove i playersFighted if (random 101) > 100 - dropRate [create-weapons 1 [
                                                              set item-level min(list random ((item 2 i) + 3) 100) + 1 ;;max ilvl is 2 more than players ilvl, can't be more than 100
                                                              set crit (random 66 + 0.1) ;; max crit is 65, doesnt depend on ilvl 0.1 added to avoid 0 errors
                                                              set strength min(list ((item 2 i) / 1.5 + random 50) 99) ;; 75% of strenth based on ilvl + 50 based on random, max strength is 99
                                                              set speed ((item 2 i) / 200 + random-float 0.5) ;;50% of speed based on ilvl + 50% based on random max is 0.99
                                                              set maxPrice 0
                                                              set basePrice 0
                                                              set startPrice 0
                                                              set minPrice 0
                                                              setxy (16) (item 1 i);;get player ycor
                                                              set originYcor (item 1 i)
                                                              set shape "line"
                                                              ];; item generation
    ask players with [ycor = (item 1 i)][set lootCounter (lootCounter + 1)]]]
end

to run-players
  check-winner
  if finishedGame[watch one-of players with [winner = true] stop]
  rest
  offer
  fight
  equip
  move-players
end


to offer
  ;; each player will look for the best weapon they can afford and move it to their offer spot, using originYcor to know who is the owner
  foreach playerSpawns [[i] ->
    ;;recalculate value of weapons
    ;; if fighter
    if (item 1 i) = 5 [ask weapons with [xcor = 16] [set basePrice item-level * 100 * 0.5
                                                             set minPrice (item-level * 100 * 0.5 + item-level * 100 * 0.13 * crit / 65 + item-level * 100 * 0.13 * speed )
                                                             set startPrice (item-level * 100 * 0.5 + item-level * 100 * 0.25 * strength / 99)
                                                             set maxPrice (item-level * 100 * 0.5 + item-level * 100 * 0.25 * strength / 99 + item-level * 100 * 0.13 * crit / 65 + item-level * 100 * 0.13 * speed)] ]
    ;; if speedrunner
    if (item 1 i) = 45 [ask weapons with [xcor = 16] [set basePrice item-level * 100 * 0.5
                                                             set minPrice (item-level * 100 * 0.5 + item-level * 100 * 0.13 * crit / 65 + item-level * 100 * 0.13 * strength / 99 )
                                                             set startPrice (item-level * 100 * 0.5 + item-level * 100 * 0.25 * speed)
                                                             set maxPrice (item-level * 100 * 0.5 + item-level * 100 * 0.25 * speed + item-level * 100 * 0.13 * crit / 65 + item-level * 100 * 0.13 * strength / 99)] ]
    ;; if assassin
    if (item 1 i) = 135 [ask weapons with [xcor = 16] [set basePrice item-level * 100 * 0.5
                                                             set minPrice (item-level * 100 * 0.5 + item-level * 100 * 0.13 * strength / 99 + item-level * 100 * 0.13 * speed )
                                                             set startPrice (item-level * 100 * 0.5 + item-level * 100 * 0.25 * crit / 65)
                                                             set maxPrice (item-level * 100 * 0.5 + item-level * 100 * 0.25 * crit / 65 + item-level * 100 * 0.13 * strength / 99 + item-level * 100 * 0.13 * speed)] ]
    ;; get the amount of gold the player has
    let playerGold 0
    let playerPower 0
    let ownerWeapon 0
    let alreadyAsked false
    ;; only players resting can make offers
    ask players with[ycor = (item 0 i) and resting = true] [set playerGold gold set playerPower weapon-power]
    ;; get the weapons that he can afford, which are better than their equiped weapon
    let affordableWeapons weapons with[maxPrice <= playerGold and xcor = 16 and maxPrice > playerPower and ycor != (item 0 i)]
    let bestAffordableWeapon 0
    if count affordableWeapons > 0 [set bestAffordableWeapon max-one-of affordableWeapons[maxPrice]
      set ownerWeapon one-of players with[ycor = [originYcor] of bestAffordableWeapon]

      ;;check if already asked for that item
      ask players with[ycor = (item 0 i)] [set alreadyAsked member? ownerWeapon alreadyOffered]

      ;;move weapon to interested spot
      if count weapons with [xcor = 17 and ycor = (item 0 i)] = 0 [if not alreadyAsked
        [ask bestAffordableWeapon [set xcor 17 set ycor (item 0 i)] ask players with [ycor = (item 0 i)] [send-message ownerWeapon "Ask" 0 set offeredMax false set alreadyOffered lput ownerWeapon alreadyOffered]]]
    ]
  ]


end

to check-winner
  ask players[ if gold > goal and not finishedGame [set winner true set size 3 setxy 0.5 18.5 set finishedGame true
    print (word " .-------W---------..--------I--------. .--------N---------..--------N---------..---------E--------..---------R--------. ")
    print (word "| .--------------. || .--------------. || .--------------. || .--------------. || .--------------. || .--------------. |")
    print (word "| | Gold         | || | Item level   | || | Strength     | || | Crit         | || |  Speed       | || | Looted       | |")
    print (word "| |  "precision gold 0"                 "precision item-level 0"                    "precision strength 0"                 "precision crit 0"                   "precision speed 2"                 "lootCounter)
    print (word "| |              | || |              | || |              | || |              | || |              | || |              | |")
    print (word "| |              | || |              | || |              | || |              | || |              | || |              | |")
    print (word "| |              | || |              | || |              | || |              | || |              | || |              | |")
    print (word "| |              | || |              | || |              | || |              | || |              | || |              | |")
    print (word "| |              | || |              | || |              | || |              | || |              | || |              | |")
    print (word "| '--------------' || '--------------' || '--------------' || '--------------' || '--------------' || '--------------' |")
    print (word " '----------------'  '----------------'  '----------------'  '----------------'  '----------------'  '----------------'")
  ]]
end

to equip
  ;; for each player row
  foreach playerSpawns [[i] ->
    ask weapons with [ycor = (item 0 i) and xcor != 17][set xcor 16]
    ;; if fighter
    if (item 1 i) = 5 [ask weapons with [ycor = (item 0 i)] [set basePrice item-level * 100 * 0.5
                                                             set minPrice (item-level * 100 * 0.5 + item-level * 100 * 0.13 * crit / 65 + item-level * 100 * 0.13 * speed )
                                                             set startPrice (item-level * 100 * 0.5 + item-level * 100 * 0.25 * strength / 99)
                                                             set maxPrice (item-level * 100 * 0.5 + item-level * 100 * 0.25 * strength / 99 + item-level * 100 * 0.13 * crit / 65 + item-level * 100 * 0.13 * speed)] ]
    ;; if speedrunner
    if (item 1 i) = 45 [ask weapons with [ycor = (item 0 i)] [set basePrice item-level * 100 * 0.5
                                                             set minPrice (item-level * 100 * 0.5 + item-level * 100 * 0.13 * crit / 65 + item-level * 100 * 0.13 * strength / 99 )
                                                             set startPrice (item-level * 100 * 0.5 + item-level * 100 * 0.25 * speed)
                                                             set maxPrice (item-level * 100 * 0.5 + item-level * 100 * 0.25 * speed + item-level * 100 * 0.13 * crit / 65 + item-level * 100 * 0.13 * strength / 99)] ]
    ;; if assassin
    if (item 1 i) = 135 [ask weapons with [ycor = (item 0 i)] [set basePrice item-level * 100 * 0.5
                                                             set minPrice (item-level * 100 * 0.5 + item-level * 100 * 0.13 * strength / 99 + item-level * 100 * 0.13 * speed )
                                                             set startPrice (item-level * 100 * 0.5 + item-level * 100 * 0.25 * crit / 65)
                                                             set maxPrice (item-level * 100 * 0.5 + item-level * 100 * 0.25 * crit / 65 + item-level * 100 * 0.13 * strength / 99 + item-level * 100 * 0.13 * speed)] ]

    ;; equip best item
    let weaponsRow  weapons with[ycor = (item 0 i) and xcor != 17]
    ask weaponsRow [set ownerMaxPrice maxPrice
                    set ownerMinPrice minPrice
                    set ownerStartPrice startPrice
                    set originYcor (item 0 i)
    ]

    let bestWeapon 0
    if count weaponsRow > 0 [set bestWeapon max-one-of weaponsRow[maxPrice]
                             ask bestWeapon [set xcor -16]

    ]



    ;; apply stats of item equiped
    if count weaponsRow > 0 [ask players with [ycor = (item 0 i)][set speed [speed] of bestWeapon
                                         set strength [strength] of bestWeapon
                                         set item-level [item-level] of bestWeapon
                                         set crit [crit] of bestWeapon
                                         set weapon-power [maxPrice] of bestWeapon
      ]
    ]

    ;; clear excessive amount of items in the inventory (max of items inbag is 3)
    let bagWeapons weapons with[xcor = 16 and ycor = (item 0 i)]
    let trashValue 0
    if count bagWeapons > 3 [ ask min-one-of weaponsRow[maxPrice] [set trashValue basePrice * 0.5 die]
    ]
    set goldGiven goldGiven + trashValue
    ask players with [ycor = (item 0 i)][set gold gold + trashValue]

  ]
  ;;remove items from first player as its bugged
  ;;ask weapons with [ycor = (-17 + numPlayers - 1)] [die]

end

to fight
  ask players [ if ([pcolor] of patch-here = 13) [ifelse (energy < 50 * ((100 - strength ) / 100)) [set resting true] [set gold (gold + (random (9 + item-level) + 1)) set playersFighted lput (list xcor ycor item-level) playersFighted
    if (random 101 > crit) [set energy (energy - (50 * ((100 - strength ) / 100)))]
  ]]] ;; gold generation
end


to rest
  ask players [ if resting [ifelse energy < 100 [set energy energy + 0.2] [set resting false set alreadyOffered [] ]]]
end

to move-players
  ask players [ ifelse [pcolor] of patch-here = 104 and not resting [set heading -90 forward (0.1 + speed)]
    [ifelse [pcolor] of patch-here = 13 and resting [set heading 90 forward (0.1 + speed)]
      [if [pcolor] of patch-here = 32 [forward (0.1 + speed)]]]
  ]
end


to setup-throne
  ask patch 1 20 [ set pcolor 85]
  ask patch 1 19 [ set pcolor black]
  ask patch 2 19 [ set pcolor 85]
  ask patch 2 18 [ set pcolor black]
  ask patch 1 18 [ set pcolor 1]

  ask patch 0 20 [ set pcolor 85]
  ask patch 0 19 [ set pcolor black]
  ask patch -1 19 [ set pcolor 85]
  ask patch -1 18 [ set pcolor black]
  ask patch 0 18 [ set pcolor 1]
end

to setup-market
  set counterSpawn numPlayers
  while [counterSpawn != 0] [ask patch 15 (counterSpawn - 18) [ set pcolor 104]
                             ask patch 16 (counterSpawn - 18) [ set pcolor 63]
                             ask patch 17 (counterSpawn - 18) [ set pcolor 105]
                             ask patch 18 (counterSpawn - 18) [ set pcolor 105]
                             set counterspawn counterspawn - 1]
end

to setup-persons
  set counterSpawn numPlayers
  while [counterSpawn != 0] [let class one-of [5 45 135] ;; fighter(gray), speedrunner(yellow), assassin(pink)
                            create-players 1 [
                            set next-messages []
                            set shape "person"
                            set resting false
                            set item-level 1
                            set strength 0
                            set crit 0
                            set speed 0.1
                            set gold 0
                            set loot false
                            set winner false
                            set energy 100
                            set heading 90
                            set offeredMax false
                            set color class
                            set alreadyOffered []
                            setxy 15 (counterSpawn - 18)
                            set lootCounter 0

                            ]
                             set counterspawn counterspawn - 1
                             set playerSpawns lput (list (counterSpawn - 17) class) playerSpawns]


end

to setup-battleground
  set counterSpawn numPlayers
  while [counterSpawn != 0] [ask patch -15 (counterSpawn - 18) [ set pcolor 13]
                             ask patch -16 (counterSpawn - 18) [ set pcolor 113]
                             ask patch -17 (counterSpawn - 18) [ set pcolor 23]
                             ask patch -18 (counterSpawn - 18) [ set pcolor 23]
                             set counterspawn counterspawn - 1]
end







to swap-messages
  ask players [
    set current-messages next-messages
    set next-messages []
  ]
end

to process-messages
  ask players [
    foreach current-messages [ ?1 ->
      process-message (item 0 ?1) (item 1 ?1) (item 2 ?1) ;; Cada mensaje es una lista [emisor tipo mensaje]
    ]
  ]
end





to process-ask-message [sender message]
  let resposta 999999999
  ask weapons with [xcor = 17 and ycor = [ycor] of sender] [set resposta ownerMaxPrice]
  ifelse resposta = 0 [ask weapons with [xcor = 17 and ycor = [ycor] of sender] [set ycor ([ycor] of self) set xcor 16]][send-message sender "Init" resposta print (word self " El preu inicial és: " resposta " -Demanat per: " sender)]


end


to process-init-message [sender message]
  let interestedS 0
  let interestedMin 0
  let interestedM 0
  ask weapons with [xcor = 17 and ycor = [ycor] of self] [set interestedS startPrice set interestedMin minPrice set interestedM maxPrice]
  ifelse message <= interestedS [send-message sender "Buy" message print (word self " Et compro l'arma per " message " -Comprat a: " sender)]
  [ifelse message > interestedS and message < interestedM [send-message sender "Offer" interestedS set offeredMax false print (word self " T'ofereixo: " interestedS " -Ofert a: " sender)]
    [send-message sender "Offer" interestedM set offeredMax true print (word self " T'ofereixo el meu max.: " interestedM " -Ofert a: " sender)]
  ]
end

to process-buy-message [sender message]
  ask sender [set gold gold - message]
  set goldFromFees (goldFromFees + message * feePercent + baseFee)
  set gold (gold + message * (1 - feePercent) - baseFee)
  ask weapons with [xcor = 17 and ycor = [ycor] of sender] [set xcor 16]
  print (word self " Venguda arma per: " message " -Vengut a: " sender)
  set counterTrades counterTrades + 1
end

to process-offer-message [sender message]
  let sellerS 0
  let sellerMin 0
  let sellerM 0
  ask weapons with [xcor = 17 and ycor = [ycor] of sender] [set sellerS ownerStartPrice set sellerMin OwnerMinPrice set sellerM ownerMaxPrice]
  ifelse message < sellerMin [ask weapons with [xcor = 17 and ycor = [ycor] of sender] [set xcor 16 set ycor originYcor] print (word self " No et venc l'arma per " message " -Denegat a: " sender)]
  [ifelse message > sellerMin and message < sellerS [send-message sender "Counter" sellerS print (word self " Contraoferto: " sellerS " -Ofert a: " sender)]
    [ask sender [set gold gold - message]
     set goldFromFees (goldFromFees + message * feePercent + baseFee)
     set gold (gold + message * (1 - feePercent) - baseFee)
     ask weapons with [xcor = 17 and ycor = [ycor] of sender] [set xcor 16]
     print (word self " Venguda arma per: " message " -Vengut a: " sender)
     set counterTrades counterTrades + 1]
  ]
end

to process-counter-message [ sender message ]
  let interestedS 0
  let interestedMin 0
  let interestedM 0
  ask weapons with [xcor = 17 and ycor = [ycor] of self] [set interestedS startPrice set interestedMin minPrice set interestedM maxPrice]

  ifelse offeredMax [ifelse message > interestedM
    [ask weapons with [xcor = 17 and ycor = [ycor] of self] [set xcor 16 set ycor originYcor] print (word self " No et compro l'arma per " message " -Retornat a: " sender)]
    [send-message sender "Buy" message print (word self " Et compro l'arma per " message " -Comprat a: " sender)]
  ][ifelse message > interestedM
    [send-message sender "Offer" interestedM set offeredMax true print (word self " T'ofereixo el meu max.: " interestedM " -Ofert a: " sender)]
    [send-message sender "Buy" message print (word self " Et compro l'arma per " message " -Comprat a: " sender)]
  ]
end



;; Ejemplo de estructura para procesar mensajes de diferente tipo
to process-message [sender kind message]

  if kind = "Ask" [
    process-ask-message sender message
  ]

  if kind = "Init" [
    process-init-message sender message
  ]

  if kind = "Buy" [
    process-buy-message sender message
  ]

  if kind = "Offer" [
    process-offer-message sender message
  ]

  if kind = "Counter" [
    process-counter-message sender message
  ]
end


to send-message [recipient kind message]
  ;; Añadimos el mensaje a la cola de mensajes del agente receptor
  ;; (se añade a next-messages para que el receptor no lo vea hasta la siguiente iteración)

  ask recipient [
    set next-messages lput (list myself kind message) next-messages
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
141
10
928
798
-1
-1
19.0
1
10
1
1
1
0
1
1
1
-20
20
-20
20
1
1
1
ticks
30.0

BUTTON
3
10
66
43
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
3
106
140
139
numPlayers
numPlayers
2
32
32.0
1
1
NIL
HORIZONTAL

BUTTON
75
10
138
43
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
3
140
140
173
dropRate
dropRate
0
100
9.0
1
1
NIL
HORIZONTAL

INPUTBOX
3
45
139
105
goal
40.0
1
0
Number

SLIDER
3
174
140
207
baseFee
baseFee
0
100
21.0
1
1
NIL
HORIZONTAL

SLIDER
3
208
141
241
feePercent
feePercent
0
1
0.21
0.01
1
NIL
HORIZONTAL

PLOT
929
10
1892
221
Gold chart
Player ID
Amount of gold owned
0.0
32.0
0.0
100.0
true
true
"set-plot-background-color approximate-rgb 20 20 20" ""
PENS
"Gold owned" 1.0 1 -1184463 true "" "plot-pen-reset\nforeach sort players [ [t] -> ask t [ plot gold] ]"
"Mean of gold owned" 1.0 0 -13345367 true "" "plot-pen-reset\nforeach sort players [plot mean [gold] of players]"

PLOT
929
223
1892
434
Items chart
Player ID
Amount of items looted
0.0
32.0
0.0
10.0
true
true
"set-plot-background-color approximate-rgb 20 20 20" ""
PENS
"Items looted" 1.0 1 -5298144 true "" "plot-pen-reset\nforeach sort players [ [t] -> ask t [ plot lootCounter] ]"
"Mean of items looted" 1.0 0 -14070903 true "" "plot-pen-reset\nforeach sort players [plot mean [lootCounter] of players]"
"Player item level" 1.0 1 -11085214 true "" "plot-pen-reset\nforeach sort players [ [t] -> ask t [ plot item-level] ]"

PLOT
929
435
1892
643
Server Gold
Ticks
Gold amount
0.0
10.0
0.0
10.0
true
true
"set-plot-background-color approximate-rgb 20 20 20" ""
PENS
"Gold given for items" 1.0 0 -723837 true "" "plot goldGiven"
"Gold obtained by fees" 1.0 0 -13840069 true "" "plot goldFromFees"

PLOT
929
644
1892
797
Trades
Gold amount
Ticks
0.0
10.0
0.0
10.0
true
true
"set-plot-background-color approximate-rgb 20 20 20" ""
PENS
"Amount of trades" 1.0 0 -11221820 true "" "plot counterTrades"
"Server item level" 1.0 0 -2674135 true "" "plot mean [item-level] of players"

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.4
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
