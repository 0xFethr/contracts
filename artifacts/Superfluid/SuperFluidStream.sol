// initializing the CFA Library
pragma solidity 0.8.14;

import { ISuperfluid, ISuperToken } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {IConstantFlowAgreementV1} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
import {CFAv1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/CFAv1Library.sol";


contract SuperFluidStream{
    using CFAv1Library for CFAv1Library.InitData;
    CFAv1Library.InitData public cfaV1;               
    address owner;
    constructor(ISuperfluid host , address _owner){
        // this contrcutor is making a call to the host contract of superfluid , that is why we need the host address 
        cfaV1 = CFAv1Library.InitData(
    host,
  
    IConstantFlowAgreementV1(
        address(host.getAgreementClass(
                keccak256("org.superfluid-finance.agreements.ConstantFlowAgreement.v1")
            ))
    )
);
owner = _owner;
    }

    function sendTokenToContract(uint amount , ISuperToken token) external{
        token.transferFrom(msg.sender ,address(this) , amount);
    }

    function createFlowToAddress(address reciever , ISuperToken token , int96 flowRate) external {
        cfaV1.createFlow(reciever , token , flowRate);
    }

    function updateFlowFromContract(address reciver , ISuperToken token , int96 flowRate) external {
        cfaV1.updateFlow(reciver , token , flowRate);
    }

    function deleteFlowFromContract(address reciever , ISuperToken token ) external{
        cfaV1.deleteFlow(address(this) , reciever , token);
    }

    function createFlowIntoContract(ISuperToken token , int96 flowRate) external{
        cfaV1.createFlowByOperator(msg.sender , address(this) , token , flowRate);
    }

    function updateFlowIntoContract(ISuperToken token , int96 flowRate) external {
         cfaV1.updateFlowByOperator(msg.sender , address(this) , token , flowRate);
    }

    function deleteFlowIntoContract(address reciever , ISuperToken token ) external{
        cfaV1.deleteFlow(msg.sender , address(this)  , token);
    }

    function withdrawFunds(ISuperToken token , uint amount ) external {
        token.transfer(msg.sender ,amount );
    }

}
