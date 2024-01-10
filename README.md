# Hive Open Polls

Decentralized polls software and an open polls protocol for the Hive ecosystem.

## What

This repository contains the specification for a protocol for creating and voting on polls utilizing the Hive blockchain. It also contains the software for backend nodes that implement the protocol. These nodes provide an API which any Hive app or frontend can easily use to implement polls.

## How it works

The Hive blockchain provides a way to store immutable data. Accounts can add data formatted as polls and poll votes, according to a mutually agreed upon open protocol. Anyone can spin up a polls API node which collects the polls data in a more standard database, interprets it according to the protocol and makes the interpreted data readily available to apps and frontends. All of this constitutes a decentralized polls system.

## Hive Open Polls Protocol - Specification

The protocol has versions, such that the software implementation can apply the correct protocol rules according to which version was used when a poll author created a poll. 

The protocol is designed to give poll authors and voters options to create and participate in polls in the way they wish to. The protocol does not specify which options or procedures should be followed in any poll but rather which options and procedures are available to choose from.

Current Version - 0.1

**Polls**

A poll is a regular Hive post (root comment). The post's `json_metadata` field is used to define it as a poll. The `json_metadata` field contains a json object such as the following:

```
{
  content_type: "poll",
  version: 0.1,
  question: "How many polls do you want to see per day?",
  choices: ["Less than 1", 1, 2, "three", "4-ish", "V", "six", 7, "e8t", "nine", 10, "10+"],
  preferred_interpretation: "tokens",
  token: "HIVE:HP",
  filters: ["account_age": 100],
  end_time: 1699373655
}
```

Where:

**content_type** defines the post as a poll  
**version** specifies the Polls Protocol version. The poll and any votes on it will be interpreted according to the version specified here, at poll creation.  
**question** contains the poll question  
**choices** contains an array with choices (answers) that can be voted on. The array order is fixed at poll creation and cannot be changed. When accounts vote, their votes are recorded as the choice number in the array.  
**preferred_interpretation** specifies the decision mechanism the poll author wishes to use for determining the poll results. It can be one of the following:
- **tokens**: choice support level is determined by how much tokens the choice voters collectively have.
- **number_of_votes**: choice support level is determined by how many accounts have voted for the choice.  

**token** specifies the token to be used for the voting calculation. The field contains the chain or layer 2 followed by the token name, for example: `HIVE:HP`, `SPL:SPSP`, `HE:SWAP.HIVE`. Required when the **tokens** option is selected for **preferred_interpretation** and not applicable otherwise.  
**filters** contains filters or requirements that accounts have to meet in order for their vote to be counted towards the poll results. In array format. Can be one or more of:
- **account_age**: the minimum account age, in days, at the time the account casts a vote.  

**end_time** specifies the time at which the poll ends. Votes made afterwards don't count towards the poll results. In UNIX timestamp.

Utilizing a regular post as the poll offers multiple advantages. It allows the poll author to add any text and multimedia in the post body along with the poll. This ability to expand on and describe the poll's question becomes especially relevant for polls asking people to vote on decisions of importance. Since a regular Hive post is used, the poll also benefits from being integrated into communities, post feeds, account profiles and so on. It also enables people to post comments under the poll's post.

Once a poll is created, it cannot be changed. Changes to the metadata that define the poll are ignored. If a poll author wishes to change any of the poll settings or choices, they have to create a new poll. This avoids issues where people vote on a poll and afterwards the poll is changed. The post body, however, can be changed in the standard way a post is edited. This allows a post author to edit the accompanying text/multimedia so as to clarify any aspect of the poll. At the same time, the blockchain keeps each version of the post which gives poll participants the ability to see how the post body was changed during the duration of the poll.

**Poll Votes**

A poll vote is a custom_json operation such as the following:

```
{
  id: 'polls',
  json: {
    "poll": 123456,
    "action": "vote",
    "choice": 1
  }
}
```

Where:

**id** serves as the unique identifier of the custom_json operation  
**poll** refers to the poll for which the vote was placed. This field contains the transaction ID of the comment operation of the poll post.  
**action** contains the activity performed on the poll, in this case a vote  
**choice** specifies the poll answer which is being voted for. This is the answer number from the poll's **choices** field, starting the counting from 1.

A voter can change their choice by making a new custom_json operation for voting on the same poll and specifying a different choice number. The new vote replaces any previous votes on the poll - any previous votes are simply ignored. If a voter wants to remove their vote rather than change it, they can specify 0 in the **choice** field.

## Polls API Nodes

To be added when the node software is developed.