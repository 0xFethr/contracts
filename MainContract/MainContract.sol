// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/utils/Counters.sol";
pragma solidity 0.8.14;

contract MainContract {
    using Counters for Counters.Counter;
    Counters.Counter public currPostID;
    address  payable immutable public owner;
    Post[] public allPosts;
    mapping(address => User) public allUsers;
    mapping(bytes32 => mapping(address =>bool))roleMapping;
    bytes32 constant ADMIN = keccak256(abi.encodePacked("ADMIN"));
    bytes32 constant COOWNER = keccak256(abi.encodePacked("COOWNER"));
    error UserAlreadyPresent();
    error UserNotPresent();
    error NotOwner();
    error NotTheRequiredRole();
    error NotEnoughFunds();
    struct User {
        address wallet;
        uint [] likedPosts;
        address[] subscribedUsers;
    }

    struct Post {
        address poster;
        uint id;
        uint upVotes;
        uint downVotes;
        uint views;
        string [] ipfsImages;
        string ipfsText;
        bool takenDown;
        
    }


    modifier onlyOwner {
        if(msg.sender != owner){
            revert NotOwner();
        }
        _;
    }

    modifier ownerOrCowner(){
        if(!roleMapping[COOWNER][msg.sender] || msg.sender == owner){
            revert NotTheRequiredRole();
        }
        _;
    }

    modifier anyRole(){
        if(!roleMapping[COOWNER][msg.sender] || msg.sender != owner || !roleMapping[ADMIN][msg.sender]){
            revert NotTheRequiredRole();
        }
        _;
    }


    modifier userPresentCheck {
        if(allUsers[msg.sender].wallet != address(0)){
            revert UserAlreadyPresent();
        }
        _;
    }
    modifier userNotPresentCheck {
         if(allUsers[msg.sender].wallet == address(0)){
            revert UserNotPresent();
        }
        _;
    }

    constructor( ) payable {
        owner =payable(msg.sender);
    }

    function grantCoOwnerRole() public onlyOwner{
        roleMapping[COOWNER][msg.sender] = true;
    }

    function grantAdminRole() public ownerOrCowner {
        roleMapping[ADMIN][msg.sender] = true;
    }

    function createUser() public userPresentCheck{
        allUsers[msg.sender].wallet  = msg.sender;
        allUsers[msg.sender].likedPosts.push(0); 
        allUsers[msg.sender].subscribedUsers.push(address(0));
    }

    function createPost(string[] memory _ipfsImages , string memory _ipfsText ) public userNotPresentCheck {
        allPosts.push(Post(msg.sender , currPostID.current() , 0 ,0 , 0 ,_ipfsImages , _ipfsText , false ));
    }
    function getUser() public view returns(User memory){
        return allUsers[msg.sender];
    }

    function getPost(uint index) public view returns(Post memory){
        return allPosts[index];
    }
    function deletePost(uint index) public {
        require(allPosts[index].poster == msg.sender , "You must be the owner of the Post");
        allPosts[index] = allPosts[allPosts.length - 1];
        allPosts.pop();
    }

    function getAllValidPosts() public view returns(Post [] memory){
        uint n  =allPosts.length;
        uint size=0;
        for(uint i=0;i<n;++i){
            if(!allPosts[i].takenDown)size++;

        }
        Post [] memory res = new Post[](n) ; 
        uint itr=0;
        for(uint i=0 ;i<n;++i){
            if(!allPosts[i].takenDown){
                res[itr] = allPosts[itr];
                itr++;
            }

        }

        return res;
    }

    function makePostInvalid(uint index) public anyRole{
        allPosts[index].takenDown = true;

    }

    function withdrawFunds(uint amount) ownerOrCowner public {
        if(address(this).balance < amount){
            revert NotEnoughFunds();
        }
        payable(msg.sender).call{value : amount}("");
    }

 
    

}